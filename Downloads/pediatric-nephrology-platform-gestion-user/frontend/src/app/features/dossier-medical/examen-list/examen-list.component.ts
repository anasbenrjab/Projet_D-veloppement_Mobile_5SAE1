import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-examen-list',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="examen-list">
      <h2><i class="fas fa-flask"></i> Examens et Analyses</h2>
      <p>Module en cours de développement...</p>
      <p>Patient ID: {{ patientId }}</p>
    </div>
  `,
  styles: [`
    .examen-list {
      padding: 2rem;
      text-align: center;
      color: #7f8c8d;
    }
    .examen-list h2 {
      color: #2c3e50;
      margin-bottom: 1rem;
    }
  `]
})
export class ExamenListComponent {
  @Input() patientId!: string;
}
