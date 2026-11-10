package tn.pedialink.notification.dto;

import lombok.Data;
import tn.pedialink.notification.model.Notification;

@Data
public class NotificationUpdateRequest {
    private Notification.Priorite priorite;
    private String titre;
    private String message;
    private Boolean lue;
    private String actionEffectuee;
    private Notification.CanalNotification canal;
}
