package com.redhat.greeter;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

@QuarkusTest
public class GreetingResourceTest {

    @Test
    public void testHelloEndpoint() {
        String version = System.getProperty("java.version");
        given()
          .when().get("/hello")
          .then()
             .statusCode(200)
             .body(is(version));
    }

}