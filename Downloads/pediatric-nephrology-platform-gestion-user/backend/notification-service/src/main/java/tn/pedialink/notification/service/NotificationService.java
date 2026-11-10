package tn.pedialink.notification.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import tn.pedialink.notification.dto.NotificationCreateRequest;
import tn.pedialink.notification.dto.NotificationResponse;
import tn.pedialink.notification.exception.ResourceNotFoundException;
import tn.pedialink.notification.model.Notification;
import tn.pedialink.notification.repository.NotificationRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    public NotificationResponse creerNotification(NotificationCreateRequest request) {
        Notification notification = Notification.builder()
                .destinataireId(request.getDestinataireId())
                .destinataireType(request.getDestinataireType())
                .type(request.getType())
                .priorite(request.getPriorite())
                .titre(request.getTitre())
                .message(request.getMessage())
                .actionUrl(request.getActionUrl())
                .canal(request.getCanal())
                .dateDeclenchement(request.getDateDeclenchement())
                .recurrente(request.getRecurrente() != null ? request.getRecurrente() : false)
                .patternRecurrence(request.getPatternRecurrence())
                .referenceId(request.getReferenceId())
                .referenceType(request.getReferenceType())
                .actionRequise(request.getActionRequise())
                .lue(false)
                .historiqueEnvois(new java.util.ArrayList<>())
                .dateCreation(LocalDateTime.now())
                .build();

        if (notification.getDateDeclenchement() == null ||
                notification.getDateDeclenchement().isBefore(LocalDateTime.now())) {
            envoyerNotification(notification);
        }

        Notification saved = notificationRepository.save(notification);
        return mapToResponse(saved);
    }

    public List<NotificationResponse> getNotificationsNonLues(String destinataireId) {
        return notificationRepository.findByDestinataireIdAndLueFalseOrderByDateCreationDesc(destinataireId)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    public void marquerCommeLue(String notificationId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ResourceNotFoundException("Notification non trouvée"));

        notification.setLue(true);
        notification.setDateLecture(LocalDateTime.now());
        notificationRepository.save(notification);
    }

    public long getNombreNotificationsNonLues(String destinataireId) {
        return notificationRepository.countByDestinataireIdAndLueFalse(destinataireId);
    }

    @Scheduled(cron = "0 */5 * * * ?")
    public void traiterNotificationsPlanifiees() {
        List<Notification> aEnvoyer = notificationRepository
                .findPendingNotifications(LocalDateTime.now());

        for (Notification notification : aEnvoyer) {
            envoyerNotification(notification);
            notificationRepository.save(notification);
        }

        if (!aEnvoyer.isEmpty()) {
            log.info("{} notifications traitées", aEnvoyer.size());
        }
    }

    @Scheduled(cron = "0 0 2 * * ?")
    public void nettoyerAnciennesNotifications() {
        LocalDateTime threshold = LocalDateTime.now().minusYears(1);
        List<Notification> anciennes = notificationRepository.findOldReadNotifications(threshold);

        notificationRepository.deleteAll(anciennes);
        log.info("{} anciennes notifications supprimées", anciennes.size());
    }

    private void envoyerNotification(Notification notification) {
        switch (notification.getCanal()) {
            case PUSH:
                envoyerPush(notification);
                break;
            case SMS:
                envoyerSMS(notification);
                break;
            case EMAIL:
                envoyerEmail(notification);
                break;
            case IN_APP:
                break;
        }

        Notification.Envoi envoi = Notification.Envoi.builder()
                .canal(notification.getCanal())
                .dateEnvoi(LocalDateTime.now())
                .statut(Notification.StatutEnvoi.ENVOYEE)
                .build();

        notification.getHistoriqueEnvois().add(envoi);
    }

    private void envoyerPush(Notification notification) {
        log.info("Envoi PUSH à {}: {}", notification.getDestinataireId(), notification.getTitre());
    }

    private void envoyerSMS(Notification notification) {
        log.info("Envoi SMS à {}: {}", notification.getDestinataireId(), notification.getTitre());
    }

    private void envoyerEmail(Notification notification) {
        log.info("Envoi EMAIL à {}: {}", notification.getDestinataireId(), notification.getTitre());
    }

    private NotificationResponse mapToResponse(Notification n) {
        return NotificationResponse.builder()
                .id(n.getId())
                .destinataireId(n.getDestinataireId())
                .destinataireType(n.getDestinataireType())
                .type(n.getType())
                .priorite(n.getPriorite())
                .titre(n.getTitre())
                .message(n.getMessage())
                .actionUrl(n.getActionUrl())
                .canal(n.getCanal())
                .lue(n.getLue())
                .dateLecture(n.getDateLecture())
                .actionRequise(n.getActionRequise())
                .actionEffectuee(n.getActionEffectuee())
                .dateAction(n.getDateAction())
                .dateDeclenchement(n.getDateDeclenchement())
                .referenceId(n.getReferenceId())
                .referenceType(n.getReferenceType())
                .dateCreation(n.getDateCreation())
                .historiqueEnvois(n.getHistoriqueEnvois().stream()
                        .map(e -> NotificationResponse.EnvoiResponse.builder()
                                .canal(e.getCanal())
                                .dateEnvoi(e.getDateEnvoi())
                                .statut(e.getStatut())
                                .build())
                        .collect(Collectors.toList()))
                .build();
    }
}
