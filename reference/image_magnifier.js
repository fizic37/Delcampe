// inst/app/www/image_magnifier.js
// Magnifying glass functionality for combined image outputs

/**
 * Initialize magnifying glass on an image element
 * @param {string} imageId - The ID of the image element to add magnification to
 * @param {number} zoomLevel - Magnification level (default: 2)
 * @param {number} lensSize - Size of the magnifying glass in pixels (default: 150)
 */
function initImageMagnifier(imageId, zoomLevel = 2, lensSize = 150) {
  const img = document.getElementById(imageId);
  if (!img) {
    console.error(`Image with ID "${imageId}" not found`);
    return null;
  }

  // Create magnifying lens element
  const lens = document.createElement('div');
  lens.className = 'magnifier-lens';
  lens.style.width = `${lensSize}px`;
  lens.style.height = `${lensSize}px`;
  lens.style.display = 'none';
  
  // Insert lens after image
  img.parentElement.insertBefore(lens, img.nextSibling);

  // Calculate the ratio between result DIV and lens
  const cx = lensSize / 2;
  const cy = lensSize / 2;

  // Set background properties for the lens
  lens.style.backgroundImage = `url('${img.src}')`;
  lens.style.backgroundRepeat = 'no-repeat';
  lens.style.backgroundSize = `${img.width * zoomLevel}px ${img.height * zoomLevel}px`;

  // Function to move the magnifying lens
  function moveMagnifier(e) {
    e.preventDefault();
    
    // Get cursor position
    const pos = getCursorPos(e);
    
    // Calculate lens position
    let x = pos.x - cx;
    let y = pos.y - cy;
    
    // Prevent lens from going outside image bounds
    if (x > img.width - lensSize) x = img.width - lensSize;
    if (x < 0) x = 0;
    if (y > img.height - lensSize) y = img.height - lensSize;
    if (y < 0) y = 0;
    
    // Set lens position
    lens.style.left = `${x}px`;
    lens.style.top = `${y}px`;
    
    // Display what the lens "sees"
    lens.style.backgroundPosition = 
      `-${x * zoomLevel - cx}px -${y * zoomLevel - cy}px`;
  }

  // Get cursor position relative to image
  function getCursorPos(e) {
    const rect = img.getBoundingClientRect();
    const x = e.pageX - rect.left - window.pageXOffset;
    const y = e.pageY - rect.top - window.pageYOffset;
    return { x, y };
  }

  // Event listeners for mouse movement
  img.addEventListener('mouseenter', () => {
    lens.style.display = 'block';
  });

  img.addEventListener('mouseleave', () => {
    lens.style.display = 'none';
  });

  img.addEventListener('mousemove', moveMagnifier);
  lens.addEventListener('mousemove', moveMagnifier);

  // Touch support for mobile devices
  img.addEventListener('touchstart', (e) => {
    lens.style.display = 'block';
    moveMagnifier(e.touches[0]);
  });

  img.addEventListener('touchmove', (e) => {
    e.preventDefault();
    moveMagnifier(e.touches[0]);
  });

  img.addEventListener('touchend', () => {
    lens.style.display = 'none';
  });

  return {
    destroy: function() {
      img.removeEventListener('mousemove', moveMagnifier);
      img.removeEventListener('mouseenter', null);
      img.removeEventListener('mouseleave', null);
      lens.removeEventListener('mousemove', moveMagnifier);
      if (lens.parentElement) {
        lens.parentElement.removeChild(lens);
      }
    },
    setZoom: function(newZoom) {
      zoomLevel = newZoom;
      lens.style.backgroundSize = `${img.width * zoomLevel}px ${img.height * zoomLevel}px`;
    },
    setLensSize: function(newSize) {
      lensSize = newSize;
      lens.style.width = `${lensSize}px`;
      lens.style.height = `${lensSize}px`;
    }
  };
}

// Auto-initialize magnifiers on page load for elements with data-magnifier attribute
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-magnifier]').forEach(img => {
    const zoom = parseFloat(img.getAttribute('data-magnifier-zoom')) || 2;
    const size = parseInt(img.getAttribute('data-magnifier-size')) || 150;
    initImageMagnifier(img.id, zoom, size);
  });
});

// Make function available globally for Shiny
window.initImageMagnifier = initImageMagnifier;

// Custom message handler for Shiny integration
if (typeof Shiny !== 'undefined') {
  Shiny.addCustomMessageHandler('initMagnifier', function(data) {
    setTimeout(function() {
      initImageMagnifier(data.imageId, data.zoom, data.lensSize);
    }, 100);
  });
  
  Shiny.addCustomMessageHandler('updateMagnifierZoom', function(data) {
    const magnifier = window.magnifiers && window.magnifiers[data.imageId];
    if (magnifier && magnifier.setZoom) {
      magnifier.setZoom(data.zoom);
    }
  });
}
