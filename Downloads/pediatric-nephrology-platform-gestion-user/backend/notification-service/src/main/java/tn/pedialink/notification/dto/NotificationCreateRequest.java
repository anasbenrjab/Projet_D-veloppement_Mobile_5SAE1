package tn.pedialink.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import tn.pedialink.notification.model.Notification;

import java.time.LocalDateTime;

@Data
public class NotificationCreateRequest {

    @NotBlank
    private String destinataireId;

    private String destinataireType;

    @NotNull
    private Notification.TypeNotification type;

    @NotNull
    private Notification.Priorite priorite;

    @NotBlank
    private String titre;

    @NotBlank
    private String message;

    private String actionUrl;

    @NotNull
    private Notification.CanalNotification canal;

    private LocalDateTime dateDeclenchement;
    private Boolean recurrente;
    private String patternRecurrence;

    private String referenceId;
    private String referenceType;
    private Boolean actionRequise;
}
