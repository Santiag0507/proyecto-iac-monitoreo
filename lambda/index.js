const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");

const client = new DynamoDBClient();

exports.handler = async (event) => {
  try {
    const body = event.body ? typeof event.body === "string" ? JSON.parse(event.body) : event.body : {};

    const device_id = body.device_id || "unknown";
    const value2 = body.value2 !== undefined ? body.value2.toString() : "0";

    const command = new PutItemCommand({
      TableName: process.env.DYNAMO_TABLE,
      Item: {
        device_id: { S: body.device_id || "unknown" },
        timestamp: { N: Date.now().toString() },
        value: { N: value2 },
      },
    });

    await client.send(command);

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Datos guardados correctamente" }),
    };
  } catch (err) {
    console.error("ERROR en Lambda:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Fallo en Lambda", error: err.message }),
    };
  }
};
