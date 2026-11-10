package tn.pedialink.notification.repository;

import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;
import tn.pedialink.notification.model.Notification;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface NotificationRepository extends MongoRepository<Notification, String> {

    List<Notification> findByDestinataireIdAndLueFalseOrderByDateCreationDesc(String destinataireId);

    List<Notification> findByDestinataireIdOrderByDateCreationDesc(String destinataireId);

    @Query("{ 'dateDeclenchement': { $lte: ?0 }, 'historiqueEnvois.statut': { $ne: 'ENVOYEE' } }")
    List<Notification> findPendingNotifications(LocalDateTime now);

    List<Notification> findByTypeAndPriorite(Notification.TypeNotification type, Notification.Priorite priorite);

    @Query("{ 'destinataireId': ?0, 'lue': false, 'priorite': 'URGENTE' }")
    List<Notification> findUnreadUrgentByDestinataire(String destinataireId);

    List<Notification> findByReferenceIdAndReferenceType(String referenceId, String referenceType);

    @Query("{ 'destinataireId': ?0, 'historiqueEnvois.statut': 'ENVOYEE' }")
    List<Notification> findSentHistoryByDestinataire(String destinataireId);

    @Query("{ 'historiqueEnvois.statut': 'ECHOUEE', 'dateCreation': { $gte: ?0 } }")
    List<Notification> findFailedSince(LocalDateTime since);

    @Query("{ 'lue': true, 'dateLecture': { $lt: ?0 } }")
    List<Notification> findOldReadNotifications(LocalDateTime threshold);

    long countByDestinataireIdAndLueFalse(String destinataireId);
}
