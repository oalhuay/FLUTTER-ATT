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
  // 1. Extraer identificadores básicos
  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type || req.query.topic;

  console.log(`🔔 Notificación recibida: ID ${id} | Tipo: ${type}`);

  // 2. Filtrar solo pagos (ignorar merchant_order)
  if (type !== "payment") {
    console.log(`⏩ Ignorando notificación de tipo: ${type}`);
    return res.status(200).send("OK");
  }

  // Responder 200 OK a Mercado Pago inmediatamente
  res.status(200).send("OK");

  if (!id) return;

  try {
    // 3. Obtener detalles del pago desde Mercado Pago
    const { data: payment } = await axios.get(
      `https://api.mercadopago.com/v1/payments/${id}`,
      { headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` } }
    );

    if (payment.status === "approved") {
      console.log(`✅ Pago #${id} aprobado. Procesando reserva...`);

      // Recuperamos la Metadata que enviamos desde reserva_screen.dart
      const metadata = payment.metadata || {};
      const userId = payment.external_reference || metadata.user_id;
      const paymentId = id.toString();

      // 4. Procesar PDF y Base de Datos en una Promesa (Para Vercel)
      await new Promise((resolve, reject) => {
        const doc = new PDFDocument();
        let buffers = [];
        doc.on("data", buffers.push.bind(buffers));

        // --- DISEÑO DEL PDF ---
        doc
          .fontSize(25)
          .fillColor("#3ABEF9")
          .text("ATT! A TODO TRAPO", { align: "center" });
        doc.moveDown();
        doc
          .fontSize(10)
          .fillColor("black")
          .text(`Comprobante #${paymentId}`, { align: "right" });
        doc.text(`Fecha Emisión: ${new Date().toLocaleDateString()}`, {
          align: "right",
        });
        doc.moveDown();
        doc
          .fontSize(14)
          .text(`Lavadero: ${metadata.lavadero_nombre || "Sucursal ATT!"}`);
        doc.text(
          `TURNO AGENDADO: ${metadata.fecha_turno} a las ${metadata.hora_turno}hs`
        );
        doc.text(`Servicios: ${metadata.servicios || "Lavado Premium"}`);
        doc.moveDown();
        doc
          .fontSize(20)
          .fillColor("#EF4444")
          .text(`TOTAL PAGADO: $${payment.transaction_amount}`);
        doc.end();

        doc.on("end", async () => {
          try {
            const pdfBuffer = Buffer.concat(buffers);
            const fileName = `tickets/factura_${paymentId}.pdf`;

            // A. Subir PDF a Storage
            await supabase.storage
              .from("comprobantes")
              .upload(fileName, pdfBuffer, {
                contentType: "application/pdf",
                upsert: true,
              });

            const {
              data: { publicUrl },
            } = supabase.storage.from("comprobantes").getPublicUrl(fileName);

            // B. Registrar Factura
            await supabase.from("facturas").insert({
              payment_id: paymentId,
              status: "approved",
              total: payment.transaction_amount,
              user_id: userId,
              servicios: metadata.servicios || "Reserva ATT",
              fecha_emision: new Date().toISOString(),
              url_pdf: publicUrl,
            });

            // C. AGENDAR TURNO CON DATOS REALES DE FLUTTER
            const { error: errTurno } = await supabase.from("turnos").insert({
              user_id: userId,
              payment_id: paymentId,
              estado: "activo",
              monto_pagado: payment.transaction_amount,
              fecha: metadata.fecha_turno, // <--- DATO DE FLUTTER
              hora: metadata.hora_turno, // <--- DATO DE FLUTTER
              lavadero_nombre: metadata.lavadero_nombre,
              servicios: metadata.servicios,
              url_comprobante: publicUrl,
            });

            if (errTurno) throw errTurno;

            console.log("📅 Turno agendado exitosamente en Supabase.");
            resolve();
          } catch (e) {
            console.error("❌ Error en persistencia:", e.message);
            reject(e);
          }
        });
      });
    }
  } catch (error) {
    console.error("⚠️ Error Webhook:", error.message);
  }
});
if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => console.log(`🚀 Servidor ATT local activo`));
}

module.exports = app;
