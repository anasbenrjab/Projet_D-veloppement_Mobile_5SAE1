# 🚀 Guide de Démarrage Rapide - Fonctionnalités Avancées

## 📋 Prérequis

- ✅ MongoDB Atlas configuré
- ✅ Services backend (prescription-service, treatment-service) démarrés
- ✅ API Gateway en cours d'exécution
- ✅ Frontend Angular compilé

---

## 🎯 Accès aux Fonctionnalités

### Pour les Parents

#### 1. Suivi d'Observance Médicamenteuse
**Accès**: Menu Parent → "Observance" ou `/parent/adherence`

**Utilisation**:
1. Cliquez sur "+ Enregistrer une prise"
2. Sélectionnez une prescription active
3. Choisissez le médicament
4. Indiquez si le médicament a été pris
5. Si oublié, précisez la raison
6. Notez les effets secondaires éventuels
7. Enregistrez

**Statistiques affichées**:
- Taux d'observance (%)
- Niveau: EXCELLENT/BON/MOYEN/FAIBLE
- Total prises vs oubliées

#### 2. Suivi de Progression du Traitement
**Accès**: Menu Parent → "Progression" ou `/parent/progress`

**Utilisation**:
1. Cliquez sur "+ Enregistrer un suivi"
2. Sélectionnez la date
3. Évaluez les symptômes (échelle 1-10)
4. Entrez poids et taille (optionnel)
5. Indiquez votre humeur
6. Évaluez énergie et sommeil
7. Ajoutez des notes
8. Enregistrez

**Analyse disponible**:
- Évolution des symptômes
- Variation de poids
- Niveau moyen d'énergie et sommeil

---

### Pour les Médecins

#### 3. Tableau de Bord Analytique
**Accès**: Menu Doctor → "Analytics" ou `/doctor/analytics`

**Fonctionnalités**:
- Statistiques personnelles de prescription
- Top 10 médicaments prescrits
- Répartition par statut
- Taux de renouvellement
- Interactions médicamenteuses fréquentes

**Filtres disponibles**:
- 7 derniers jours
- 30 derniers jours
- 90 derniers jours
- 1 an

---

## 🔧 Test des Fonctionnalités

### Test Backend

#### 1. Tester l'API Adherence
```bash
# Enregistrer une prise
curl -X POST http://localhost:8080/api/v1/adherence/log \
  -H "Content-Type: application/json" \
  -H "X-User-Id: patient-test" \
  -d '{
    "prescriptionId": "PRESCRIPTION_ID",
    "medicamentNom": "Paracétamol",
    "datePrise": "2026-02-26T10:00:00",
    "prise": true,
    "notes": "Pris avec le petit déjeuner"
  }'

# Obtenir les statistiques
curl http://localhost:8080/api/v1/adherence/stats/patient-test?jours=30
```

#### 2. Tester l'API Progress
```bash
# Enregistrer un suivi
curl -X POST http://localhost:8080/api/v1/progress/log \
  -H "Content-Type: application/json" \
  -H "X-User-Id: patient-test" \
  -d '{
    "treatmentId": "TREATMENT_ID",
    "date": "2026-02-26",
    "symptomes": {
      "fatigue": 5,
      "douleur": 3
    },
    "poids": 45.5,
    "niveauEnergie": 7,
    "qualiteSommeil": 8
  }'

# Obtenir l'analyse
curl http://localhost:8080/api/v1/progress/analyze/TREATMENT_ID?jours=30
```

#### 3. Tester l'API Analytics
```bash
# Statistiques médecin
curl http://localhost:8080/api/v1/analytics/medecin/doctor-test?jours=30

# Top médicaments
curl http://localhost:8080/api/v1/analytics/medicaments/top?jours=30&limit=10

# Interactions fréquentes
curl http://localhost:8080/api/v1/analytics/interactions/frequentes
```

---

## 🐛 Dépannage Rapide

### Problème: Routes 404

**Solution**:
```bash
# Redémarrer API Gateway
cd backend/api-gateway
mvn spring-boot:run
```

### Problème: Données non affichées

**Vérifications**:
1. MongoDB Atlas accessible
2. Services backend démarrés
3. Logs des services:
```bash
# Vérifier les logs
tail -f backend/prescription-service/logs/app.log
tail -f backend/treatment-service/logs/app.log
```

### Problème: CORS Errors

**Solution**: Vérifier `application.yml` dans API Gateway:
```yaml
globalcors:
  corsConfigurations:
    '[/**]':
      allowedOrigins: "http://localhost:4200"
      allowedMethods: [GET, POST, PUT, DELETE, OPTIONS]
      allowedHeaders: "*"
      allowCredentials: true
```

---

## 📊 Données de Test

### Créer une prescription de test
```bash
curl -X POST http://localhost:8080/api/v1/prescriptions \
  -H "Content-Type: application/json" \
  -H "X-User-Id: doctor-test" \
  -d '{
    "patientId": "patient-test",
    "diagnostic": "Infection respiratoire",
    "datePrescription": "2026-02-26",
    "dureeValiditeJours": 30,
    "medicaments": [{
      "nomCommercial": "Doliprane",
      "dci": "Paracétamol",
      "dosage": "500mg",
      "posologie": {
        "quantite": 1,
        "unite": "comprimé",
        "frequence": "3 fois par jour"
      }
    }],
    "renouvelable": true
  }'
```

### Créer un traitement de test
```bash
curl -X POST http://localhost:8080/api/v1/traitements \
  -H "Content-Type: application/json" \
  -H "X-User-Id: doctor-test" \
  -d '{
    "patientId": "patient-test",
    "diagnostic": "Asthme",
    "dateDebut": "2026-02-01",
    "dateFin": "2026-03-01",
    "objectifTraitement": "Contrôle des symptômes",
    "notes": "Traitement de fond",
    "medicaments": [{
      "nomCommercial": "Ventoline",
      "dci": "Salbutamol",
      "formePharmaceutique": "Inhalateur",
      "dosage": "100mcg",
      "posologie": {
        "quantite": 2,
        "unite": "bouffées",
        "frequence": "2 fois par jour"
      }
    }],
    "recommandations": ["Éviter les allergènes", "Exercice régulier"]
  }'
```

---

## ✅ Checklist de Vérification

### Backend
- [ ] prescription-service démarré sur port 8083
- [ ] treatment-service démarré sur port 8084
- [ ] API Gateway démarré sur port 8080
- [ ] MongoDB Atlas accessible
- [ ] Routes configurées dans API Gateway

### Frontend
- [ ] Angular dev server démarré (port 4200)
- [ ] Routes ajoutées dans app.routes.ts
- [ ] Navigation mise à jour (parent et doctor)
- [ ] Services HTTP créés
- [ ] Composants compilés sans erreur

### Tests
- [ ] Adherence: Enregistrement d'une prise
- [ ] Adherence: Affichage des statistiques
- [ ] Progress: Enregistrement d'un suivi
- [ ] Progress: Affichage de l'analyse
- [ ] Analytics: Affichage des statistiques médecin
- [ ] Analytics: Top médicaments
- [ ] Navigation: Tous les liens fonctionnent

---

## 🎓 Scénarios d'Utilisation

### Scénario 1: Parent suit l'observance

1. Parent se connecte
2. Va dans "Observance"
3. Voit ses prescriptions actives
4. Enregistre chaque prise quotidienne
5. Consulte son taux d'observance
6. Partage avec le médecin lors du RDV

### Scénario 2: Parent suit la progression

1. Parent se connecte
2. Va dans "Progression"
3. Enregistre quotidiennement:
   - Symptômes (fatigue, douleur, etc.)
   - Poids
   - Énergie et sommeil
4. Consulte l'analyse automatique
5. Identifie les tendances
6. Discute avec le médecin

### Scénario 3: Médecin analyse ses prescriptions

1. Médecin se connecte
2. Va dans "Analytics"
3. Consulte ses statistiques
4. Identifie les médicaments les plus prescrits
5. Vérifie les interactions fréquentes
6. Optimise ses pratiques

---

## 📞 Support

### Logs à consulter
```bash
# Backend
tail -f backend/prescription-service/logs/app.log
tail -f backend/treatment-service/logs/app.log
tail -f backend/api-gateway/logs/app.log

# Frontend
# Ouvrir la console du navigateur (F12)
```

### Commandes utiles
```bash
# Redémarrer tous les services
cd backend
./restart-all.sh

# Vérifier MongoDB
mongo "mongodb+srv://PediaLink:PediaLink@pedialink.0d8a5qd.mongodb.net/pedialink"

# Vérifier Eureka
curl http://localhost:8761/eureka/apps
```

---

## 🎉 Prochaines Étapes

1. ✅ Tester toutes les fonctionnalités
2. ✅ Créer des données de test
3. ✅ Valider les calculs statistiques
4. ⏳ Ajouter des graphiques (Chart.js)
5. ⏳ Implémenter les notifications
6. ⏳ Export PDF des rapports

---

**Version**: 1.0.0  
**Date**: 26 février 2026  
**Statut**: ✅ Prêt pour tests
