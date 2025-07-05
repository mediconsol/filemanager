// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "bootstrap"

// Hospital Management Analysis System JavaScript

// Initialize Bootstrap tooltips and popovers
document.addEventListener('DOMContentLoaded', function() {
  // Initialize tooltips
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  var tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl)
  })

  // Initialize popovers
  var popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
  var popoverList = popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl)
  })
})

// File upload drag and drop functionality
function initializeFileUpload() {
  const uploadArea = document.querySelector('.upload-area')
  if (!uploadArea) return

  uploadArea.addEventListener('dragover', function(e) {
    e.preventDefault()
    uploadArea.classList.add('dragover')
  })

  uploadArea.addEventListener('dragleave', function(e) {
    e.preventDefault()
    uploadArea.classList.remove('dragover')
  })

  uploadArea.addEventListener('drop', function(e) {
    e.preventDefault()
    uploadArea.classList.remove('dragover')
    
    const files = e.dataTransfer.files
    handleFileUpload(files)
  })
}

// Handle file upload
function handleFileUpload(files) {
  const formData = new FormData()
  
  for (let i = 0; i < files.length; i++) {
    formData.append('files[]', files[i])
  }
  
  // Show progress indicator
  showUploadProgress()
  
  // Upload files via AJAX
  fetch('/data_uploads', {
    method: 'POST',
    body: formData,
    headers: {
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    }
  })
  .then(response => response.json())
  .then(data => {
    hideUploadProgress()
    if (data.success) {
      showAlert('Files uploaded successfully!', 'success')
    } else {
      showAlert('Upload failed: ' + data.error, 'danger')
    }
  })
  .catch(error => {
    hideUploadProgress()
    showAlert('Upload error: ' + error.message, 'danger')
  })
}

// Show upload progress
function showUploadProgress() {
  const progressHtml = `
    <div id="upload-progress" class="alert alert-info">
      <div class="d-flex align-items-center">
        <div class="spinner-border spinner-border-sm me-2" role="status"></div>
        <span>Uploading files...</span>
      </div>
    </div>
  `
  document.body.insertAdjacentHTML('afterbegin', progressHtml)
}

// Hide upload progress
function hideUploadProgress() {
  const progress = document.getElementById('upload-progress')
  if (progress) {
    progress.remove()
  }
}

// Show alert message
function showAlert(message, type) {
  const alertHtml = `
    <div class="alert alert-${type} alert-dismissible fade show" role="alert">
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
  `
  document.body.insertAdjacentHTML('afterbegin', alertHtml)
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  initializeFileUpload()
})

// Export functions for global use
window.HospitalAnalysis = {
  handleFileUpload,
  showAlert,
  showUploadProgress,
  hideUploadProgress
}
