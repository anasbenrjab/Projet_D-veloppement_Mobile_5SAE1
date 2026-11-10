import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-dialyse-list',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="dialyse-list">
      <h2><i class="fas fa-heartbeat"></i> Séances de Dialyse</h2>
      <p>Module en cours de développement...</p>
      <p>Patient ID: {{ patientId }}</p>
    </div>
  `,
  styles: [`
    .dialyse-list {
      padding: 2rem;
      text-align: center;
      color: #7f8c8d;
    }
    .dialyse-list h2 {
      color: #2c3e50;
      margin-bottom: 1rem;
    }
  `]
})
export class DialyseListComponent {
  @Input() patientId!: string;
}
