const express = require("express");
const cors = require("cors");
const { createClient } = require("@supabase/supabase-js");
const axios = require("axios");
require("dotenv").config();
const cors = require("cors");
const { MercadoPagoConfig, Preference } = require("mercadopago");
const PDFDocument = require("pdfkit"); //
const app = express();
app.use(cors());
app.use(express.json());
const allowedOrigins = [
  "https://flutter-att.vercel.app", // Tu dominio de front-end
  "https://flutter-att-8xz7.vercel.app", // Tu dominio de servidor
  "http://localhost:3000", // Para pruebas locales
  "http://localhost:5000",
];
app.use(
  cors({
    origin: function (origin, callback) {
      // Permitir peticiones sin origen (como apps móviles o curl)
      if (!origin) return callback(null, true);

      if (allowedOrigins.indexOf(origin) === -1) {
        const msg =
          "El policy de CORS para este sitio no permite acceso desde el origen especificado.";
        return callback(new Error(msg), false);
      }
      return callback(null, true);
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);
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

app.post("/webhook", async (req, res) => {
  // 1. Respuesta inmediata para Mercado Pago
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
        console.log("-----------------------------------------");
        console.log("💰 PROCESANDO PAGO APROBADO:", id);
        console.log("Metadata:", JSON.stringify(payment.metadata, null, 2));
        console.log("-----------------------------------------");

        const userId = payment.external_reference;
        const paymentId = id.toString();
        const metadata = payment.metadata || {}; //

        // --- A. GENERAR PDF EN MEMORIA ---
        const doc = new PDFDocument();
        let buffers = [];
        doc.on("data", buffers.push.bind(buffers));

        // Diseño del PDF (ATT! 2040)
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

        // --- B. ESPERAR A QUE EL PDF TERMINE Y SUBIRLO ---
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

            console.log("📄 PDF subido correctamente:", publicUrl);

            // 3. Registrar Factura
            const { error: errorFactura } = await supabase
              .from("facturas")
              .insert({
                payment_id: paymentId,
                status: "approved",
                total: payment.transaction_amount,
                user_id: userId,
                servicios: payment.description || "Reserva ATT",
                fecha_emision: new Date().toISOString(),
                url_pdf: publicUrl, // Guardamos el link en la factura
              });

            if (errorFactura)
              console.error("❌ Error Factura:", errorFactura.message);

            // 4. Registrar Turno
            const { error: errorTurno } = await supabase.from("turnos").insert({
              user_id: userId,
              payment_id: paymentId,
              estado: "activo", // Cambiado a 'activo' para tu filtro de Flutter
              monto_pagado: payment.transaction_amount,
              fecha:
                metadata.fecha_turno || new Date().toISOString().split("T")[0],
              hora: metadata.hora_turno || "00:00",
              lavadero_nombre: metadata.lavadero_nombre || "Lavadero ATT",
              servicios: payment.description || "Reserva ATT",
              url_comprobante: publicUrl, // El cliente ya tiene el link listo
            });

            if (errorTurno) {
              console.error("❌ Error Turno:", errorTurno.message);
            } else {
              console.log("📅 Turno y Factura vinculados exitosamente.");
            }
          } catch (dbErr) {
            console.error("🚨 Error en Storage/Base de Datos:", dbErr.message);
          }
        });
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
