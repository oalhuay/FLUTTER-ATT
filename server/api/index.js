const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios"); // Movido arriba para mejor rendimiento
require("dotenv").config();

// 1. IMPORTAR SDK NUEVO
const { MercadoPagoConfig, Preference } = require("mercadopago");

const app = express();
app.use(cors());
app.use(express.json());

// 2. CONFIGURAR CLIENTE MP (Esto faltaba definirlo correctamente)
const client = new MercadoPagoConfig({
  accessToken: process.env.MP_ACCESS_TOKEN,
});

// Configuración de Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// --- ENDPOINT: CREAR PREFERENCIA ---
app.post("/create-preference", async (req, res) => {
  try {
    const { titulo, precio, userId } = req.body;

    // USAR EL SDK CON EL CLIENTE DEFINIDO ARRIBA
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
          success: "att-app://pago-exitoso",
          failure: "att-app://pago-fallido",
          pending: "att-app://pago-pendiente",
        },
        auto_return: "approved",
        external_reference: userId,
        // Usamos tu URL de Vercel directamente
        notification_url: "https://flutter-att-8xz7.vercel.app/webhook",
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
  // Respuesta inmediata para Mercado Pago
  res.status(200).send("OK");

  const { query, body } = req;
  const id = query.id || (body.data && body.data.id);
  const type = query.type || body.type;

  console.log(`📩 Webhook recibido: Tipo: ${type}, ID: ${id}`);

  if (id === "123456") {
    console.log("✅ Prueba de conexión de MP exitosa.");
    return;
  }

  try {
    if (type === "payment" && id) {
      const { data: payment } = await axios.get(
        `https://api.mercadopago.com/v1/payments/${id}`,
        {
          headers: { Authorization: `Bearer ${process.env.MP_ACCESS_TOKEN}` },
        }
      );

      if (payment.status === "approved") {
        console.log("💰 Pago Aprobado. Registrando en Supabase...");

        const { error } = await supabase.from("facturas").insert({
          payment_id: id.toString(),
          status: "approved",
          total: payment.transaction_amount,
          user_id: payment.external_reference,
          servicios: "Reserva ATT",
          fecha_emision: new Date().toISOString(),
        });

        if (error) {
          console.error("❌ Error Supabase:", error.message);
        } else {
          console.log("🚀 ¡FACTURA GUARDADA CON ÉXITO!");
        }
      }
    }
  } catch (error) {
    console.error("⚠️ Error procesando datos del pago:", error.message);
  }
});

// Condición para que funcione en Local y en Vercel
if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 3001;
  app.listen(PORT, () => {
    console.log(`🚀 Servidor ATT local en puerto ${PORT}`);
  });
}

module.exports = app;
