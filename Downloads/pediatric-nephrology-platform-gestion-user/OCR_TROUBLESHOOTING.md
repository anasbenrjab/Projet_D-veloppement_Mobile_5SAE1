# 🔧 OCR Scanner Troubleshooting Guide

## ❌ Error: "Error processing image. Please try again"

### Causes Possibles

1. **Backend non démarré**
   - Le service prescription-service n'est pas en cours d'exécution
   - L'API Gateway n'est pas démarré

2. **Route non configurée**
   - La route `/api/prescriptions/ai/**` n'est pas dans l'API Gateway

3. **CORS bloqué**
   - Le navigateur bloque la requête cross-origin

4. **Image invalide**
   - Format non supporté (doit être JPG ou PNG)
   - Taille > 5MB

### Solutions

#### 1. Vérifier que les services sont démarrés

```bash
# Vérifier prescription-service (port 8084)
curl http://localhost:8084/actuator/health

# Vérifier API Gateway (port 8080)
curl http://localhost:8080/actuator/health
```

#### 2. Vérifier la route dans API Gateway

Le fichier `backend/api-gateway/src/main/resources/application.yml` doit contenir:

```yaml
- id: prescription-ai-service
  uri: lb://prescription-service
  predicates:
    - Path=/api/prescriptions/ai/**
```

#### 3. Redémarrer les services

```bash
# Arrêter tous les services
# Puis redémarrer dans l'ordre:

# 1. Config Server (si utilisé)
# 2. Eureka Server
# 3. API Gateway
# 4. Prescription Service
```

#### 4. Vérifier les logs

**Backend logs:**
```bash
# Dans IntelliJ, vérifier la console de prescription-service
# Chercher les lignes:
# "Received OCR request for image: ..."
# "Processing prescription image: ..."
```

**Frontend logs:**
```javascript
// Ouvrir la console du navigateur (F12)
// Chercher:
// "Scanning prescription..."
// "OCR Response: ..."
// Erreurs HTTP
```

#### 5. Tester l'endpoint directement

```bash
# Créer un fichier test.jpg
# Tester avec curl:

curl -X POST http://localhost:8080/api/prescriptions/ai/ocr/extract \
  -F "image=@test.jpg" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Vérifications Rapides

✅ **Checklist:**
- [ ] Prescription-service est démarré (port 8084)
- [ ] API Gateway est démarré (port 8080)
- [ ] Eureka Server est démarré (port 8761)
- [ ] Route AI ajoutée dans application.yml
- [ ] Image est JPG ou PNG
- [ ] Image < 5MB
- [ ] Token JWT valide
- [ ] CORS configuré correctement

## 🔍 Debugging Steps

### Étape 1: Vérifier la connexion backend

Ouvrir la console du navigateur et vérifier:
```javascript
// URL appelée
console.log('API URL:', environment.apiUrl + '/prescriptions/ai/ocr/extract');

// Devrait être: http://localhost:8080/api/prescriptions/ai/ocr/extract
```

### Étape 2: Vérifier la requête

Dans l'onglet Network (F12):
1. Chercher la requête `ocr/extract`
2. Vérifier le Status Code:
   - 200: OK
   - 400: Bad Request (image invalide)
   - 401: Non autorisé (token manquant)
   - 404: Route non trouvée
   - 500: Erreur serveur

3. Vérifier la réponse:
```json
{
  "success": true,
  "diagnostic": "...",
  "medicaments": [...]
}
```

### Étape 3: Vérifier les headers

La requête doit avoir:
```
Content-Type: multipart/form-data
Authorization: Bearer <token>
```

## 🐛 Erreurs Communes

### 1. "Cannot connect to server"

**Cause:** Backend non accessible

**Solution:**
```bash
# Vérifier que le backend écoute sur le bon port
netstat -an | grep 8080  # API Gateway
netstat -an | grep 8084  # Prescription Service
```

### 2. "Invalid image format"

**Cause:** Format d'image non supporté

**Solution:**
- Utiliser JPG ou PNG uniquement
- Convertir l'image si nécessaire
- Vérifier que le fichier n'est pas corrompu

### 3. "File size exceeds maximum"

**Cause:** Image > 5MB

**Solution:**
- Compresser l'image
- Réduire la résolution
- Utiliser un outil de compression en ligne

### 4. "401 Unauthorized"

**Cause:** Token JWT manquant ou expiré

**Solution:**
- Se reconnecter
- Vérifier que le token est envoyé dans les headers
- Vérifier la validité du token

## 📊 Mode Debug

Pour activer le mode debug détaillé:

**Backend (application.yml):**
```yaml
logging:
  level:
    tn.pedialink.prescription: DEBUG
    org.springframework.web: DEBUG
```

**Frontend (environment.ts):**
```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api',
  debug: true  // Ajouter cette ligne
};
```

## ✅ Test de Fonctionnement

Pour vérifier que tout fonctionne:

1. **Test Backend Direct:**
```bash
curl -X POST http://localhost:8084/api/prescriptions/ai/ocr/extract \
  -F "image=@test.jpg"
```

2. **Test via API Gateway:**
```bash
curl -X POST http://localhost:8080/api/prescriptions/ai/ocr/extract \
  -F "image=@test.jpg" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

3. **Test Frontend:**
   - Ouvrir http://localhost:4200
   - Se connecter comme médecin
   - Aller dans Prescriptions
   - Cliquer "Scan Prescription"
   - Uploader une image
   - Vérifier la console pour les logs

## 📞 Support

Si le problème persiste:

1. Copier les logs du backend
2. Copier les erreurs de la console navigateur
3. Noter les étapes pour reproduire
4. Vérifier la version de Java (doit être 17+)
5. Vérifier la version de Node (doit être 18+)

## 🔄 Reset Complet

Si rien ne fonctionne, reset complet:

```bash
# 1. Arrêter tous les services
# 2. Nettoyer les builds
cd backend
mvn clean

cd ../frontend
rm -rf node_modules
npm install

# 3. Rebuild
cd backend
mvn clean install -DskipTests

cd ../frontend
npm run build

# 4. Redémarrer dans l'ordre
# Config Server → Eureka → Gateway → Services
```

## 📝 Notes

- Le mode simulé fonctionne sans clés API
- Les vraies APIs nécessitent Google Cloud ou DeepL
- Les logs sont dans `backend/prescription-service/logs/`
- La taille max d'upload est configurable dans application.yml
