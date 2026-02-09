const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
require("dotenv").config();
const { MercadoPagoConfig, Preference } = require("mercadopago");
const PDFDocument = require("pdfkit");

const app = express();

// --- 1. CONFIGURACIÓN DE CORS Y CONTROL DE PRE-VUELO (OPTIONS) ---
const allowedOrigins = [
  "https://flutter-att.vercel.app",
  "https://flutter-att-8xz7.vercel.app",
  "http://localhost:3000",
];

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (allowedOrigins.includes(origin)) {
    res.header("Access-Control-Allow-Origin", origin);
  } else {
    res.header("Access-Control-Allow-Origin", "https://flutter-att.vercel.app");
  }
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
  res.header(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization, X-Requested-With"
  );
  res.header("Access-Control-Allow-Credentials", "true");

  // Respuesta inmediata para el Preflight (Resuelve: "It does not have HTTP ok status")
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }
  next();
});

app.use(express.json());

// --- 2. CONFIGURACIÓN DE CLIENTES ---
const client = new MercadoPagoConfig({
  accessToken: process.env.MP_ACCESS_TOKEN,
});

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// --- 3. ENDPOINT: CREAR PREFERENCIA ---
app.post("/create-preference", async (req, res) => {
  try {
    const { titulo, precio, userId, metadata } = req.body;
    const preference = new Preference(client);

    const result = await preference.create({
      body: {
        items: [
          {
            title: titulo,
            quantity: 1,
            unit_price: Number(precio),
            currency_id: "ARS",
          },
        ],
        back_urls: {
          success: "https://flutter-att.vercel.app/#/pago-exitoso",
          failure: "https://flutter-att.vercel.app/#/pago-fallido",
        },
        auto_return: "approved",
        external_reference: userId,
        notification_url: "https://flutter-att-8xz7.vercel.app/webhook",
        metadata: metadata, // Importante para recuperar fecha/hora en el webhook
      },
    });

    res.json({ init_point: result.init_point });
  } catch (error) {
    console.error("❌ Error MP:", error.message);
    res.status(500).json({ error: error.message });
  }
});

// --- 4. ENDPOINT: WEBHOOK ---
app.post("/webhook", async (req, res) => {
  res.status(200).send("OK"); // Obligatorio para Mercado Pago

  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type;

  if (type === "payment" && id) {
    try {
      const { data: payment } = await axios.get(
        `https://api.mercadopago.com/v1/payments/${id}`,
        { headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` } }
      );

      if (payment.status === "approved") {
        const userId = payment.external_reference;
        const paymentId = id.toString();
        const metadata = payment.metadata || {};

        console.log(`💰 Procesando pago aprobado ${paymentId}...`);

        // --- A. GENERAR PDF ---
        const doc = new PDFDocument();
        let buffers = [];
        doc.on("data", buffers.push.bind(buffers));

        doc
          .fontSize(25)
          .fillColor("#3ABEF9")
          .text("ATT! A TODO TRAPO", { align: "center" });
        doc.moveDown();
        doc
          .fontSize(10)
          .fillColor("black")
          .text(`Comprobante #${paymentId}`, { align: "right" });
        doc.text(`Fecha: ${new Date().toLocaleDateString()}`, {
          align: "right",
        });
        doc.moveDown();
        doc
          .fontSize(14)
          .text(`Lavadero: ${metadata.lavadero_nombre || "Sucursal ATT!"}`);
        doc.text(
          `Turno: ${metadata.fecha_turno || "--"} - ${
            metadata.hora_turno || "--"
          }hs`
        );
        doc.text(`Servicio: ${payment.description || "Lavado Premium"}`);
        doc.moveDown();
        doc
          .fontSize(20)
          .fillColor("#EF4444")
          .text(`TOTAL: $${payment.transaction_amount}`, { align: "left" });
        doc.end();

        doc.on("end", async () => {
          const pdfBuffer = Buffer.concat(buffers);
          const fileName = `tickets/factura_${paymentId}.pdf`;

          try {
            // 1. Subir a Storage
            await supabase.storage
              .from("comprobantes")
              .upload(fileName, pdfBuffer, {
                contentType: "application/pdf",
                upsert: true,
              });

            const {
              data: { publicUrl },
            } = supabase.storage.from("comprobantes").getPublicUrl(fileName);

            // 2. Insertar Factura
            await supabase.from("facturas").insert({
              payment_id: paymentId,
              status: "approved",
              total: payment.transaction_amount,
              user_id: userId,
              servicios: payment.description || "Reserva ATT",
              fecha_emision: new Date().toISOString(),
              url_pdf: publicUrl,
            });

            // 3. Insertar Turno (Para "Mis Turnos" en la App)
            await supabase.from("turnos").insert({
              user_id: userId,
              payment_id: paymentId,
              estado: "activo",
              monto_pagado: payment.transaction_amount,
              fecha:
                metadata.fecha_turno || new Date().toISOString().split("T")[0],
              hora: metadata.hora_turno || "00:00",
              lavadero_nombre: metadata.lavadero_nombre || "Lavadero ATT",
              servicios: payment.description || "Reserva ATT",
              url_comprobante: publicUrl,
            });

            console.log("📅 Proceso completado: Turno y Factura vinculados.");
          } catch (dbErr) {
            console.error("🚨 Error Supabase/Storage:", dbErr.message);
          }
        });
      }
    } catch (error) {
      console.error("⚠️ Error Webhook:", error.message);
    }
  }
});

if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => console.log(`🚀 Servidor ATT local activo`));
}

module.exports = app;
