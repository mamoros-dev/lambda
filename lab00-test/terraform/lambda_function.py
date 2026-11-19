import json

def lambda_handler(event, context):
    print("--- INICIO DE EJECUCIÓN LAMBDA ---")
    print(f"Evento recibido: {json.dumps(event)}")
    
    # Lógica sencilla de negocio o saludo
    mensaje = "¡Hola, Miguel! Tu Lambda desplegada con Terraform funciona perfectamente."
    
    print("--- FIN DE EJECUCIÓN LAMBDA ---")
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensaje": mensaje,
            "estado": "Exitoso"
        })
    }
