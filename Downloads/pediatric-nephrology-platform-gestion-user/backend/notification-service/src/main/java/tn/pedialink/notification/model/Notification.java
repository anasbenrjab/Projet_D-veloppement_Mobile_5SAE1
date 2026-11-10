package tn.pedialink.notification.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "notifications")
@CompoundIndexes({
        @CompoundIndex(name = "destinataire_non_lues_idx", def = "{'destinataireId': 1, 'lue': 1, 'dateCreation': -1}"),
        @CompoundIndex(name = "type_priorite_idx", def = "{'type': 1, 'priorite': 1}"),
        @CompoundIndex(name = "trigger_date_idx", def = "{'dateDeclenchement': 1}")
})
public class Notification {

    @Id
    private String id;

    @NotBlank
    private String destinataireId;

    private String destinataireType;

    @NotNull
    private TypeNotification type;

    @NotNull
    private Priorite priorite;

    @NotBlank
    private String titre;

    @NotBlank
    private String message;

    private String actionUrl;

    @NotNull
    private CanalNotification canal;

    @Builder.Default
    private List<Envoi> historiqueEnvois = new ArrayList<>();

    private Boolean lue;
    private LocalDateTime dateLecture;

    private Boolean actionRequise;
    private String actionEffectuee;
    private LocalDateTime dateAction;

    private LocalDateTime dateDeclenchement;
    private Boolean recurrente;
    private String patternRecurrence;

    private String referenceId;
    private String referenceType;

    @CreatedDate
    private LocalDateTime dateCreation;

    @LastModifiedDate
    private LocalDateTime dateModification;

    public enum TypeNotification {
        RAPPEL_RDV,
        ALERTE_RENOUVELLEMENT,
        RAPPEL_PRISE_MEDICAMENT,
        ALERTE_INTERACTION,
        ALERTE_CONTRE_INDICATION,
        RAPPEL_BILAN,
        PRESCRIPTION_EXPIREE,
        TRAITEMENT_TERMINE,
        MESSAGE_MEDECIN,
        RESULTAT_BILAN_DISPONIBLE,
        ALERTE_OBSERVANCE
    }

    public enum Priorite {
        BASSE, NORMALE, HAUTE, URGENTE
    }

    public enum CanalNotification {
        PUSH, SMS, EMAIL, IN_APP
    }

    public enum StatutEnvoi {
        EN_ATTENTE, ENVOYEE, LUE, ECHOUEE, DESACTIVEE
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Envoi {
        private CanalNotification canal;
        private LocalDateTime dateEnvoi;
        private StatutEnvoi statut;
        private String erreur;
        private String messageId;
    }
}
