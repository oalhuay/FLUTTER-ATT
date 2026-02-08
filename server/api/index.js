const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
require("dotenv").config();

// 1. IMPORTAR SDK NUEVO
const { MercadoPagoConfig, Preference } = require("mercadopago");

const app = express();
app.use(cors());
app.use(express.json());

// Configuración de Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// 2. CONFIGURAR CLIENTE MP
const client = new MercadoPagoConfig({
  accessToken:
    "APP_USR-8115934189968230-020621-d0d2756b4bf4d74e164719cfa54e050d-1899785327",
});

// --- ENDPOINT: CREAR PREFERENCIA ---
app.post("/create-preference", async (req, res) => {
  try {
    const { titulo, precio, userId } = req.body;

    // 3. USAR EL SDK PARA LA PREFERENCIA
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
        // RECUERDA: Cambia esto por tu URL actual de Ngrok si pruebas Webhooks
        notification_url:
          "https://risky-aleisha-chemically.ngrok-free.app/webhook",
      },
    });

    // El SDK devuelve el init_point dentro del resultado
    res.json({ init_point: result.init_point });
  } catch (error) {
    console.error("Error SDK MP:", error);
    res.status(500).json({ error: error.message });
  }
});

app.post("/webhook", async (req, res) => {
  // 1. RESPUESTA INSTANTÁNEA: Esto mata el error 502
  res.status(200).send("OK");

  const { query, body } = req;
  const id = query.id || (body.data && body.data.id);
  const type = query.type || body.type;

  console.log(`📩 Webhook recibido: Tipo: ${type}, ID: ${id}`);

  // 2. Si es la prueba de Mercado Pago (ID 123456), no hacemos nada más
  if (id === "123456") {
    console.log("✅ Prueba de conexión de MP exitosa.");
    return;
  }

  // 3. Procesamos pagos reales en segundo plano
  try {
    if (type === "payment" && id) {
      // Importante: Usamos fetch o axios para buscar el detalle
      const axios = require("axios");
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
          user_id: payment.external_reference, // El userId que mandamos desde Flutter
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
    // Error silencioso para no romper el flujo
    console.error("⚠️ Error procesando datos del pago:", error.message);
  }
});

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`🚀 Servidor ATT con SDK Oficial en puerto ${PORT}`);
});
