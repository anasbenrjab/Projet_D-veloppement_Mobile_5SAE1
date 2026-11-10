package tn.pedialink.notification.dto;

import lombok.Builder;
import lombok.Data;
import tn.pedialink.notification.model.Notification;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class NotificationResponse {
    private String id;
    private String destinataireId;
    private String destinataireType;
    private Notification.TypeNotification type;
    private Notification.Priorite priorite;
    private String titre;
    private String message;
    private String actionUrl;
    private Notification.CanalNotification canal;
    private Boolean lue;
    private LocalDateTime dateLecture;
    private Boolean actionRequise;
    private String actionEffectuee;
    private LocalDateTime dateAction;
    private LocalDateTime dateDeclenchement;
    private String referenceId;
    private String referenceType;
    private LocalDateTime dateCreation;
    private List<EnvoiResponse> historiqueEnvois;

    @Data
    @Builder
    public static class EnvoiResponse {
        private Notification.CanalNotification canal;
        private LocalDateTime dateEnvoi;
        private Notification.StatutEnvoi statut;
    }
}
