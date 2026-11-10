package tn.pedialink.dossiermedical.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import tn.pedialink.dossiermedical.model.consultation.StatutConsultation;
import java.time.LocalDateTime;

@Data
public class ConsultationDto {
    @NotBlank
    private String patientId;
    @NotBlank
    private String medecinId;
    @NotNull
    private LocalDateTime dateRendezVous;
    private LocalDateTime dateProposee; // Date proposée par médecin si refus
    @NotBlank
    private String motifConsultation;
    private String observationsCliniques;
    private String diagnostic;
    private String recommandations;
    private String compteRendu;
    private StatutConsultation statut;
    private String raisonRefus;
}
