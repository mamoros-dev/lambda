import json
import boto3

# Creamos el cliente de DynamoDB fuera del handler para reutilizarlo entre ejecuciones
dynamodb = boto3.client("dynamodb")


def lambda_handler(event, context):
    # Definimos el nombre de la tabla DynamoDB que crearemos en Terraform
    table_name = "lab2-eventos-demo"
    
    # Leemos qué operación queremos hacer: "guardar" o "leer".
    # Si no viene "action" en el event, usamos "leer" por defecto.
    action = event.get("action", "leer")
    
    # Leemos el ID del evento (clave primaria de la tabla)
    event_id = event.get("event_id")

    # Validación básica: sin event_id no podemos guardar ni consultar un ítem concreto
    if not event_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Falta el parámetro 'event_id' en el evento"})
        }

    if action == "guardar":
        # Obtenemos un mensaje opcional; si no se envía, ponemos uno por defecto
        mensaje = event.get("mensaje", "Evento registrado desde Lambda")

        # put_item crea o sobrescribe un ítem en la tabla DynamoDB
        dynamodb.put_item(
            TableName=table_name,
            Item={
                "event_id": {"S": str(event_id)},
                "mensaje": {"S": str(mensaje)}
            }
        )

        print(f"Guardado en DynamoDB -> event_id: {event_id} | mensaje: {mensaje}")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "accion": "guardar",
                "event_id": event_id,
                "estado": "guardado_ok"
            })
        }

    elif action == "leer":
        # get_item busca exactamente el ítem cuya clave de partición coincida con event_id
        respuesta = dynamodb.get_item(
            TableName=table_name,
            Key={
                "event_id": {"S": str(event_id)}
            }
        )

        # La respuesta de get_item incluye "Item" solo si el registro existe
        item = respuesta.get("Item")
        if not item:
            print(f"No se encontró ningún registro con event_id: {event_id}")
            return {
                "statusCode": 404,
                "body": json.dumps({"mensaje": f"No existe el registro '{event_id}'"})
            }

        # Extraemos los valores de texto ("S") del diccionario devuelto por DynamoDB
        datos_limpios = {
            "event_id": item["event_id"]["S"],
            "mensaje": item.get("mensaje", {}).get("S", "")
        }

        print(f"Leído desde DynamoDB -> {datos_limpios}")
        return {
            "statusCode": 200,
            "body": json.dumps({
                "accion": "leer",
                "datos": datos_limpios
            })
        }

    else:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": f"Acción no válida: {action}. Usa 'guardar' o 'leer'."})
        }