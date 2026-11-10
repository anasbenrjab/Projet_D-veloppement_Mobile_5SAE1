package tn.pedialink.notification.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

@Configuration
@EnableMongoRepositories(basePackages = "tn.pedialink.notification.repository")
public class MongoConfig {
}
