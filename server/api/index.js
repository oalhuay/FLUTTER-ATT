const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
require("dotenv").config();
const { MercadoPagoConfig, Preference } = require("mercadopago");
const PDFDocument = require("pdfkit");

const app = express();

// --- CORS CONFIGURACIÓN ---
app.use(
  cors({
    origin: "https://flutter-att.vercel.app",
    credentials: true,
  })
);

app.use(express.json());

// Manejo manual de OPTIONS para evitar el 500 en preflight
app.options("*", (req, res) => {
  res.header("Access-Control-Allow-Origin", "https://flutter-att.vercel.app");
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.sendStatus(200);
});

// --- CLIENTES ---
// Usamos try-catch para que si faltan las ENV, no rompa todo el servidor
const supabase = createClient(
  process.env.SUPABASE_URL || "",
  process.env.SUPABASE_SERVICE_ROLE_KEY || ""
);

const client = new MercadoPagoConfig({
  accessToken: process.env.MP_ACCESS_TOKEN || "",
});

// --- RUTA: CREAR PREFERENCIA ---
app.post("/create-preference", async (req, res) => {
  try {
    const { titulo, precio, userId, metadata } = req.body;

    if (!titulo || !precio) {
      return res.status(400).json({ error: "Faltan datos obligatorios" });
    }

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
        metadata: metadata,
      },
    });

    res.json({ init_point: result.init_point });
  } catch (error) {
    console.error("❌ Error en create-preference:", error);
    res.status(500).json({ error: error.message });
  }
});

// --- ENDPOINT: WEBHOOK ---
app.post("/webhook", async (req, res) => {
  res.status(200).send("OK");

  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type;

  if (type === "payment" && id) {
    try {
      const { data: payment } = await axios.get(
        `https://api.mercadopago.com/v1/payments/${id}`,
        {
          headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` },
        }
      );

      if (payment.status === "approved") {
        const userId = payment.external_reference;
        const paymentId = id.toString();
        const metadata = payment.metadata || {};

        // --- A. GENERAR PDF EN MEMORIA ---
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
          .text(`Comprobante de Pago #${paymentId}`, { align: "right" });
        doc.text(`Fecha: ${new Date().toLocaleDateString()}`, {
          align: "right",
        });
        doc.moveDown();
        doc
          .fontSize(14)
          .text(`Lavadero: ${metadata.lavadero_nombre || "Sucursal ATT!"}`);
        doc.text(`Servicio: ${payment.description || "Lavado Premium"}`);
        doc.text(
          `Turno: ${metadata.fecha_turno || "--"} a las ${
            metadata.hora_turno || "--"
          }hs`
        );
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
            // 1. Subir a Supabase Storage
            const { error: uploadError } = await supabase.storage
              .from("comprobantes")
              .upload(fileName, pdfBuffer, {
                contentType: "application/pdf",
                upsert: true,
              });

            if (uploadError) throw uploadError;

            // 2. Obtener la URL Pública
            const {
              data: { publicUrl },
            } = supabase.storage.from("comprobantes").getPublicUrl(fileName);

            // 3. Registrar Factura
            await supabase.from("facturas").insert({
              payment_id: paymentId,
              status: "approved",
              total: payment.transaction_amount,
              user_id: userId,
              servicios: payment.description || "Reserva ATT",
              fecha_emision: new Date().toISOString(),
              url_pdf: publicUrl,
            });

            // 4. Registrar Turno
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

            console.log("📅 Sistema procesado: PDF, Factura y Turno creados.");
          } catch (dbErr) {
            console.error("🚨 Error en Storage/Base de Datos:", dbErr.message);
          }
        });
      }
    } catch (error) {
      console.error("⚠️ Error procesando webhook:", error.message);
    }
  }
});

if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => {
    console.log(`🚀 Servidor ATT local corriendo`);
  });
}

module.exports = app;
