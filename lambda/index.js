const AWS = require("aws-sdk");
const docClient = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    try {
        // Si viene desde API Gateway (JSON body stringificado)
        const body = typeof event.body === "string" ? JSON.parse(event.body) : event.body;

        const params = {
            TableName: process.env.DYNAMO_TABLE,
            Item: {
                device_id: body.device_id || "unknown",
                timestamp: Date.now(),
                value: body.value || 0
            }
        };

        await docClient.put(params).promise();

        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Datos guardados exitosamente" })
        };
    } catch (err) {
        console.error("Error al guardar datos:", err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Error interno al guardar los datos" })
        };
    }
};
