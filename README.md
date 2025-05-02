#  Proyecto IaC – Sistema de Monitoreo Inteligente de Equipos y Energía

TECNOLOGIAS USADAS PARA LA ENTREGA:
- Terraform
- AWS Lambda – Procesamiento sin servidor
- API Gateway – Exposición de endpoints HTTP
- DynamoDB – Almacenamiento NoSQL de eventos
- CloudWatch – Monitoreo de ejecución
- IAM Roles/Policies – Control de acceso seguro
- GitHub – Control de versiones y entrega del trabajo

 # Integraciones cumplidas 

 1 Lambda + IAM Role & Policy  - Para que la función Lambda pueda acceder de forma segura a otros servicios de AWS (como CloudWatch y DynamoDB), necesita permisos.  
 2 Lambda + CloudWatch  - Esta integración permite enviar los logs a CloudWatch, lo cual es clave para depurar, auditar errores y validar que los datos se están procesando correctamente.
 3 API Gateway + Lambda (Trigger)  - Esta integración convierte tu función Lambda en una API REST pública, permitiendo que los dispositivos IoT (o cualquier cliente HTTP) puedan enviar datos usando una solicitud `POST`
 4 Lambda + DynamoDB - Los datos recibidos desde dispositivos deben almacenarse para análisis o consulta. DynamoDB ofrece alta disponibilidad y rendimiento sin administración de servidores


#DESPLIEGUE:

terraform init
terraform apply 

curl -X POST https://TU_API_GATEWAY_URL/iot \
  -H "Content-Type: application/json" \
  -d '{"device_id":"raspi01", "value":123}'


verificar en cloud y dynamo si ya se subio
