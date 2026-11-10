package tn.pedialink.dossiermedical.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.disable())  // Désactiver CORS de Spring Security
            .authorizeHttpRequests(auth -> auth
                .anyRequest().permitAll()  // Permet toutes les requêtes sans authentification
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .formLogin(form -> form.disable())  // Désactiver le formulaire de login
            .httpBasic(basic -> basic.disable());  // Désactiver l'authentification basique

        return http.build();
    }
}
