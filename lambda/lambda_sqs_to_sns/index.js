const AWS = require('aws-sdk');
const sns = new AWS.SNS();

exports.handler = async (event) => {
  for (const record of event.Records) {
    const messageBody = record.body;

    const params = {
      TopicArn: process.env.SNS_TOPIC_ARN,
      Message: messageBody
    };

    try {
      await sns.publish(params).promise();
      console.log("Mensaje reenviado a SNS:", messageBody);
    } catch (error) {
      console.error("Error al reenviar mensaje:", error);
    }
  }
};
