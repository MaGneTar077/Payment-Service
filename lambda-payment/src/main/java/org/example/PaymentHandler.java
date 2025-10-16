package org.example;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.*;
import com.amazonaws.services.dynamodbv2.document.spec.QuerySpec;
import com.amazonaws.services.dynamodbv2.document.utils.NameMap;
import com.amazonaws.services.dynamodbv2.document.utils.ValueMap;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.*;

public class PaymentHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper mapper = new ObjectMapper();
    private final AmazonSQS sqs = AmazonSQSClientBuilder.defaultClient();
    private final AmazonDynamoDB dynamoClient = AmazonDynamoDBClientBuilder.defaultClient();
    private final DynamoDB dynamoDB = new DynamoDB(dynamoClient);

    private final String startPaymentQueueUrl = System.getenv("START_PAYMENT_QUEUE_URL");
    private final String cardTableName = System.getenv("CARD_TABLE_NAME");

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
            Map<String, Object> body = mapper.readValue(request.getBody(), Map.class);
            String cardId = (String) body.get("cardId");

            if (cardId == null || cardId.isEmpty()) {
                throw new IllegalArgumentException("El campo cardId es obligatorio.");
            }

            String userId = getUserIdFromCardId(cardId);

            if (userId == null) {
                throw new IllegalArgumentException("No se encontró ningún usuario asociado a la tarjeta con ID: " + cardId);
            }

            String traceId = UUID.randomUUID().toString();

            Map<String, Object> message = new HashMap<>();
            message.put("userId", userId);
            message.put("cardId", cardId);
            message.put("service", body.get("service"));
            message.put("traceId", traceId);
            message.put("status", "INITIAL");
            message.put("timestamp", System.currentTimeMillis());

            String messageBody = mapper.writeValueAsString(message);
            sqs.sendMessage(startPaymentQueueUrl, messageBody);

            Map<String, String> result = new HashMap<>();
            result.put("traceId", traceId);

            response.setStatusCode(200);
            response.setBody(mapper.writeValueAsString(result));
        } catch (Exception e) {
            context.getLogger().log("❌ Error en PaymentHandler: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Error procesando el pago: " + e.getMessage() + "\"}");
        }

        response.setHeaders(getCorsHeaders());
        return response;
    }

    private String getUserIdFromCardId(String cardId) {
        Table table = dynamoDB.getTable(cardTableName);

        QuerySpec querySpec = new QuerySpec()
                .withKeyConditionExpression("#u = :v_id")
                .withNameMap(new NameMap().with("#u", "uuid"))
                .withValueMap(new ValueMap().withString(":v_id", cardId))
                .withMaxResultSize(1);

        ItemCollection<QueryOutcome> items = table.query(querySpec);
        Iterator<Item> iterator = items.iterator();

        if (!iterator.hasNext()) {
            return null;
        }

        Item item = iterator.next();
        return item.getString("userId");
    }

    private Map<String, String> getCorsHeaders() {
        Map<String, String> headers = new HashMap<>();
        headers.put("Access-Control-Allow-Origin", "*");
        headers.put("Access-Control-Allow-Methods", "OPTIONS,POST,GET");
        headers.put("Access-Control-Allow-Headers", "Content-Type,Authorization");
        return headers;
    }
}
