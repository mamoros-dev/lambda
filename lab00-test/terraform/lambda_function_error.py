import json

def lambda_handler(event, context):
    print("--- INICIO DE EJECUCIÓN: SIMULANDO FALLO ---")
    
    # Forzamos una excepción no controlada para que AWS Lambda registre un error
    raise Exception("¡Error crítico simulado para probar la alarma de CloudWatch!")