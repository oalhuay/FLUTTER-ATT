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
    const { titulo, precio, userId } = req.body;
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
        // CAMBIO AQUÍ: Usamos la URL limpia de producción para el webhook
        notification_url: "https://flutter-att.vercel.app/webhook",
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
  // 1. Respuesta inmediata (Obligatorio para evitar reintentos infinitos de MP)
  res.status(200).send("OK");

  const id = req.query.id || (req.body.data && req.body.data.id);
  const type = req.query.type || req.body.type;

  // Solo procesamos si el evento es un pago
  if (type === "payment" && id) {
    try {
      const { data: payment } = await axios.get(
        `https://api.mercadopago.com/v1/payments/${id}`,
        {
          headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` },
        }
      );

      // Verificamos que el estado sea aprobado
      if (payment.status === "approved") {
        console.log(`💰 Pago ${id} aprobado. Registrando...`);

        const { error } = await supabase.from("facturas").insert({
          payment_id: id.toString(),
          status: "approved",
          total: payment.transaction_amount,
          user_id: payment.external_reference, // Recuperamos el ID de Supabase enviado desde Flutter
          servicios: "Reserva ATT",
          fecha_emision: new Date().toISOString(),
        });

        if (error) {
          console.error("❌ Error al insertar en Supabase:", error.message);
        } else {
          console.log("🚀 ¡FACTURA GUARDADA CON ÉXITO EN PRODUCCIÓN!");
        }
      }
    } catch (error) {
      console.error("⚠️ Error consultando pago en MP:", error.message);
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
