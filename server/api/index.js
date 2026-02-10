const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
require("dotenv").config();
const { MercadoPagoConfig, Preference } = require("mercadopago");
const PDFDocument = require("pdfkit");

const app = express();

// --- 1. CONFIGURACIÓN DE CORS ---
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

    console.log("📦 Generando preferencia para User:", userId);
    console.log(
      "📝 Metadata recibida de Flutter:",
      JSON.stringify(metadata, null, 2)
    );

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
    console.error("❌ Error creando preferencia:", error.message);
    res.status(500).json({ error: error.message });
  }
});

// --- 4. ENDPOINT: WEBHOOK CON LOGS DETALLADOS Y FALLBACK DE DATOS ---
app.post("/webhook", async (req, res) => {
  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type || req.query.topic;

  console.log(`🔔 WEBHOOK ENTRANTE: ID ${id} | Tipo: ${type}`);

  if (type !== "payment") {
    console.log(`⏩ Ignorando ${type} (No es un pago aprobado aún)`);
    return res.status(200).send("OK");
  }

  // IMPORTANTE: En Vercel, NO respondas "OK" aquí si vas a usar procesos largos abajo,
  // a menos que uses una Promesa envolvente.

  try {
    console.log(`📡 Consultando detalles del pago ${id} a Mercado Pago...`);

    const { data: payment } = await axios.get(
      `https://api.mercadopago.com/v1/payments/${id}`,
      { headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` } }
    );

    console.log(`💳 Estado del pago: ${payment.status}`);

    if (payment.status === "approved") {
      const metadata = payment.metadata || {};
      const userId = payment.external_reference || metadata.user_id;

      console.log("📝 Iniciando inserción en Supabase...");
      console.log(payment.metadata);
      // Agrupamos las tareas en un solo bloque que DEBEMOS esperar
      await Promise.all([
        // Tarea 1: El Turno
        supabase
          .from("turnos")
          .insert({
            user_id: userId,
            payment_id: id.toString(),
            estado: "activo",
            monto_pagado: payment.transaction_amount,
            fecha: metadata.fecha_turno,
            hora: metadata.hora_turno,
            lavadero_nombre: metadata.lavadero_nombre,
            servicios: metadata.servicios || "Lavado ATT!",
          })
          .then(({ error }) => {
            if (error) console.error("❌ Error DB Turno:", error.message);
            else console.log("✅ Turno insertado correctamente");
          }),

        // Tarea 2: PDF y Factura
        procesarPDFYFactura(payment, metadata, id.toString(), userId),
      ]);

      console.log("🏁 Webhook procesado completamente.");
    }

    // Respondemos al final para asegurar que Vercel no mate el proceso antes
    return res.status(200).send("OK");
  } catch (error) {
    console.error(
      "⚠️ Error crítico en el Webhook:",
      error.response?.data || error.message
    );
    return res.status(200).send("OK"); // Respondemos OK igual para que MP no sature
  }
});

if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => console.log(`🚀 Servidor local activo`));
}

module.exports = app;
