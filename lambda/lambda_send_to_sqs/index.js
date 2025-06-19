const AWS = require('aws-sdk');
const sqs = new AWS.SQS();

exports.handler = async (event) => {
    console.log("📥 Alerta recibida:", JSON.stringify(event, null, 2));

    const mensaje = {
        alert: event.alert || "Sin alerta",
        level: event.level || "UNDEFINED",
        device_id: event.device_id || "unknown-device",
        timestamp: event.timestamp || new Date().toISOString()
    };

    const params = {
        QueueUrl: process.env.SQS_URL,
        MessageBody: JSON.stringify(mensaje)
    };

    try {
        const result = await sqs.sendMessage(params).promise();
        console.log("📤 Mensaje enviado correctamente a SQS:", result.MessageId);
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: "✅ Alerta procesada y enviada a SQS",
                data: mensaje,
                result: result.MessageId
            })
        };
    } catch (error) {
        console.error("❌ Error al enviar mensaje a SQS:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: error.message })
        };
    }
};
