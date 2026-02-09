const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
require("dotenv").config();

const { MercadoPagoConfig, Preference } = require("mercadopago");

const app = express();
app.use(cors());
app.use(express.json());

const client = new MercadoPagoConfig({
  accessToken: process.env.MP_ACCESS_TOKEN,
});

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// --- ENDPOINT: CREAR PREFERENCIA ---
app.post("/create-preference", async (req, res) => {
  try {
    const { titulo, precio, userId, metadata } = req.body; // Recibimos metadata opcional
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
          pending: "https://flutter-att.vercel.app/#/pago-pendiente",
        },
        auto_return: "approved",
        external_reference: userId,
        notification_url: "https://flutter-att-8xz7.vercel.app/webhook",
        metadata: metadata, // Pasamos info extra (fecha, hora, lavadero) si viene desde Flutter
      },
    });

    res.json({ init_point: result.init_point });
  } catch (error) {
    console.error("Error SDK MP:", error);
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

        console.log(
          `💰 Pago ${paymentId} aprobado. Procesando factura y turno...`
        );

        // 1. GUARDAR FACTURA
        const { error: errorFactura } = await supabase.from("facturas").insert({
          payment_id: paymentId,
          status: "approved",
          total: payment.transaction_amount,
          user_id: userId,
          servicios: payment.description || "Reserva ATT",
          fecha_emision: new Date().toISOString(),
        });

        if (errorFactura) {
          console.error("❌ Error Supabase (Factura):", errorFactura.message);
        } else {
          console.log("🚀 Factura guardada.");
        }

        // 2. GUARDAR TURNO (Para que aparezca en "Mis Turnos")
        // Usamos los datos que Mercado Pago nos devuelve o los que mandamos en metadata
        const { error: errorTurno } = await supabase.from("turnos").insert({
          user_id: userId,
          payment_id: paymentId,
          estado: "confirmado",
          monto_pagado: payment.transaction_amount,
          // Si envías fecha/hora en metadata al crear la preferencia, las usas aquí:
          fecha:
            payment.metadata?.fecha_turno ||
            new Date().toISOString().split("T")[0],
          hora: payment.metadata?.hora_turno || "00:00",
          lavadero_nombre: payment.metadata?.lavadero_nombre || "Lavadero ATT",
          servicios: payment.description || "Reserva ATT",
        });

        if (errorTurno) {
          console.error("❌ Error Supabase (Turno):", errorTurno.message);
        } else {
          console.log("📅 Turno registrado con éxito.");
        }
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
