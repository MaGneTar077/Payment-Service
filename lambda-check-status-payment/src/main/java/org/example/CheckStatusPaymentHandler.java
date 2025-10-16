package org.example;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.dynamodbv2.document.Table;
import com.amazonaws.services.dynamodbv2.document.spec.GetItemSpec;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.HashMap;
import java.util.Map;

public class CheckStatusPaymentHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper mapper = new ObjectMapper();
    private final AmazonDynamoDB dynamoClient = AmazonDynamoDBClientBuilder.defaultClient();
    private final DynamoDB dynamoDB = new DynamoDB(dynamoClient);
    private final String paymentTableName = System.getenv("PAYMENT_TABLE_NAME");

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent request, Context context) {

        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();

        if ("OPTIONS".equalsIgnoreCase(request.getHttpMethod())) {
            response.setStatusCode(200);
            response.setHeaders(getCorsHeaders());
            response.setBody("{}");
            return response;
        }

        try {
            String traceId = request.getPathParameters() != null ? request.getPathParameters().get("traceId") : null;

            if (traceId == null || traceId.isEmpty()) {
                response.setStatusCode(400);
                response.setHeaders(getCorsHeaders());
                response.setBody("{\"error\":\"El parámetro traceId es obligatorio\"}");
                return response;
            }

            Table table = dynamoDB.getTable(paymentTableName);

            GetItemSpec spec = new GetItemSpec().withPrimaryKey("traceId", traceId);
            Item item = table.getItem(spec);

            if (item == null) {
                response.setStatusCode(404);
                response.setHeaders(getCorsHeaders());
                response.setBody("{\"error\":\"No se encontró ningún pago con el traceId: " + traceId + "\"}");
                return response;
            }

            Map<String, Object> result = new HashMap<>();
            result.put("traceId", traceId);
            result.put("status", item.getString("status"));

            if (item.hasAttribute("error")) {
                result.put("error", item.getString("error"));
            }

            response.setStatusCode(200);
            response.setBody(mapper.writeValueAsString(result));

        } catch (Exception e) {
            context.getLogger().log("❌ Error en CheckStatusPaymentHandler: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Error consultando el estado del pago: " + e.getMessage() + "\"}");
        }

        response.setHeaders(getCorsHeaders());
        return response;
    }

    private Map<String, String> getCorsHeaders() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Access-Control-Allow-Origin", "*");
        headers.put("Access-Control-Allow-Methods", "OPTIONS,GET");
        headers.put("Access-Control-Allow-Headers", "Content-Type,Authorization");
        headers.put("Content-Type", "application/json");
        return headers;
    }
}
