const AWS = require('aws-sdk');
const sqs = new AWS.SQS();

exports.handler = async (event) => {
  const messageBody = {
    alert: event.alert || "Mensaje de prueba",
    level: event.level || "INFO",
    device_id: event.device_id || "sin_id",
    timestamp: event.timestamp || new Date().toISOString()
  };

  const params = {
    QueueUrl: process.env.SQS_URL,
    MessageBody: JSON.stringify(messageBody)
  };

  try {
    const result = await sqs.sendMessage(params).promise();
    console.log("Mensaje enviado a SQS:", result.MessageId);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Mensaje enviado correctamente", result })
    };
  } catch (error) {
    console.error("Error al enviar mensaje a SQS:", error);

    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Error al enviar mensaje a SQS", error })
    };
  }
};
