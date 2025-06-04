exports.handler = async (event) => {
  return {
    statusCode: 200,
    body: JSON.stringify({ data: "Datos del dashboard obtenidos" }),
  };
};
