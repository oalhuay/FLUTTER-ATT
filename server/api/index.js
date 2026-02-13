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

// --- 3. FUNCIÓN DE APOYO: GENERAR PDF Y FACTURA ---
// Definimos la función que faltaba para procesar el comprobante en segundo plano
async function procesarPDFYFactura(payment, metadata, paymentId, userId) {
  return new Promise((resolve) => {
    const doc = new PDFDocument();
    let buffers = [];
    doc.on("data", buffers.push.bind(buffers));


    doc
      .fontSize(25)
      .fillColor("#3ABEF9")
      .text("ATT! A TODO TRAPO", { align: "center" });
    doc.moveDown().fontSize(12).fillColor("black");
    doc.text(`Comprobante de Pago: ${paymentId}`);
    doc.text(`Servicios: ${metadata.servicios || "Lavado"}`);
    doc.text(`Turno: ${metadata.fecha_turno} - ${metadata.hora_turno}hs`);
    doc.end();

    doc.on("end", async () => {
      try {
        const pdfBuffer = Buffer.concat(buffers);
        const fileName = `tickets/factura_${paymentId}.pdf`;

        // 1. Subir a Storage
        console.log("📤 Subiendo PDF a Storage...");
        const { error: uploadError } = await supabase.storage
          .from("comprobantes")
          .upload(fileName, pdfBuffer, {
            contentType: "application/pdf",
            upsert: true,
          });

        if (uploadError) throw uploadError;

        // 2. Obtener URL Pública de forma segura
        const { data: publicUrlData } = supabase.storage
          .from("comprobantes")
          .getPublicUrl(fileName);

        const urlGenerada = publicUrlData.publicUrl;
        console.log("🔗 URL PDF GENERADA:", urlGenerada);

        // 3. Registrar Factura en DB
        console.log("📝 Intentando registrar factura en DB...");
        const { error: errorFactura } = await supabase.from("facturas").insert({
          payment_id: paymentId,
          status: "approved",
          total: payment.transaction_amount,
          user_id: userId,
          servicios: metadata.servicios || "Lavado",
          fecha_emision: new Date().toISOString(),
          url_pdf: urlGenerada,
        });

        if (errorFactura) {
          console.error("❌ Error al insertar Factura:", errorFactura.message);
        } else {
          console.log("✅ Factura registrada con éxito en Supabase.");
        }

        // 4. Actualizar Turno con la URL del comprobante
        const { error: errorTurno } = await supabase
          .from("turnos")
          .update({ url_comprobante: urlGenerada })
          .eq("payment_id", paymentId);

        if (errorTurno) {
          console.error(
            "❌ Error al actualizar turno con URL:",
            errorTurno.message
          );
        } else {
          console.log("📅 Turno actualizado con link al PDF.");
        }

        console.log("🏁 Proceso de PDF y Factura finalizado.");
        resolve();
      } catch (err) {
        console.error("❌ Error crítico en procesarPDFYFactura:", err.message);
        resolve(); // Resolvemos para no dejar colgado el Webhook
      }
    });
  });
}

// --- 4. ENDPOINT: CREAR PREFERENCIA ---
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
        metadata: metadata,
      },
    });
    res.json({ init_point: result.init_point });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// --- 5. ENDPOINT: WEBHOOK ---
app.post("/webhook", async (req, res) => {
  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type || req.query.topic;

  console.log(`🔔 WEBHOOK ENTRANTE: ID ${id} | Tipo: ${type}`);

  if (type !== "payment") {
    return res.status(200).send("OK");
  }

  try {
    const { data: payment } = await axios.get(
      `https://api.mercadopago.com/v1/payments/${id}`,
      { headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` } }
    );

    if (payment.status === "approved") {
      const metadata = payment.metadata || {};
      const userId = payment.external_reference || metadata.user_id;

      console.log("📝 Iniciando inserción en Supabase...");

      // Ejecutamos ambas tareas y esperamos su cumplimiento
      await Promise.all([
        (async () => {
          const turnoPayload = {
            user_id: userId,
            payment_id: id.toString(),
            estado: "activo",
            monto_pagado: payment.transaction_amount,
            fecha: metadata.fecha_turno,
            hora: metadata.hora_turno,
            lavadero_id: metadata.lavadero_id || null,
            lavadero_nombre: metadata.lavadero_nombre,
            servicios: metadata.servicios || "Lavado",
          };

          let { error } = await supabase.from("turnos").insert(turnoPayload);

          if (error && /lavadero_id/i.test(error.message || "")) {
            const payloadSinLavaderoId = { ...turnoPayload };
            delete payloadSinLavaderoId.lavadero_id;
            const retry = await supabase
              .from("turnos")
              .insert(payloadSinLavaderoId);
            error = retry.error;
          }

          if (error) console.error("Error DB Turno:", error.message);
          else console.log("Turno insertado correctamente");
        })(),
        procesarPDFYFactura(payment, metadata, id.toString(), userId),
      ]);

      console.log("🏁 Webhook procesado completamente.");
    }

    return res.status(200).send("OK");
  } catch (error) {
    console.error("⚠️ Error crítico en el Webhook:", error.message);
    return res.status(200).send("OK");
  }
});

if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => console.log(`🚀 Servidor local activo`));
}

module.exports = app;
