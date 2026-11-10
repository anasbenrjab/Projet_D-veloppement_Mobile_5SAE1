package tn.pedialink.notification.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import tn.pedialink.notification.dto.ApiResponse;
import tn.pedialink.notification.dto.NotificationCreateRequest;
import tn.pedialink.notification.dto.NotificationResponse;
import tn.pedialink.notification.service.NotificationService;

import java.util.List;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @PostMapping
    public ResponseEntity<ApiResponse<NotificationResponse>> creerNotification(
            @Valid @RequestBody NotificationCreateRequest request) {

        NotificationResponse response = notificationService.creerNotification(request);
        return ResponseEntity.ok(ApiResponse.created(response));
    }

    @GetMapping("/non-lues")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getNotificationsNonLues(
            @AuthenticationPrincipal UserDetails userDetails) {

        String destinataireId = userDetails != null ? userDetails.getUsername() : "user-test";
        List<NotificationResponse> notifications = notificationService.getNotificationsNonLues(destinataireId);
        return ResponseEntity.ok(ApiResponse.ok(notifications));
    }

    @GetMapping("/compteur")
    public ResponseEntity<ApiResponse<Long>> getNombreNotificationsNonLues(
            @AuthenticationPrincipal UserDetails userDetails) {

        String destinataireId = userDetails != null ? userDetails.getUsername() : "user-test";
        long count = notificationService.getNombreNotificationsNonLues(destinataireId);
        return ResponseEntity.ok(ApiResponse.ok(count));
    }

    @PutMapping("/{id}/lue")
    public ResponseEntity<ApiResponse<Void>> marquerCommeLue(@PathVariable String id) {
        notificationService.marquerCommeLue(id);
        return ResponseEntity.ok(ApiResponse.ok("Notification marquée comme lue", null));
    }

    @PutMapping("/tout-lu")
    public ResponseEntity<ApiResponse<Void>> marquerToutCommeLu(
            @AuthenticationPrincipal UserDetails userDetails) {

        String destinataireId = userDetails != null ? userDetails.getUsername() : "user-test";
        List<NotificationResponse> nonLues = notificationService.getNotificationsNonLues(destinataireId);
        nonLues.forEach(n -> notificationService.marquerCommeLue(n.getId()));

        return ResponseEntity.ok(ApiResponse.ok("Toutes les notifications marquées comme lues", null));
    }
}
