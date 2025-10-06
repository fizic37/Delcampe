// inst/app/www/draggable_lines.js - Complete coordinate mapping solution

document.addEventListener('DOMContentLoaded', () => {
  document
    .querySelectorAll('[data-draggrid]')
    .forEach(initDraggableGrid);
});

function initDraggableGrid(wrapper) {
  const prefix = wrapper.id.replace(/-grid_ui_wrapper$/, '');
  
  console.log("🎯 Initializing draggable grid for wrapper:", wrapper.id);

  const style = window.getComputedStyle(wrapper);
  if (style.position === 'static') {
    wrapper.style.position = 'relative';
  }

  const img = wrapper.querySelector('img');
  if (!img) {
    console.error('❌ No image found in wrapper!');
    return;
  }

  // Store original image dimensions
  let origWidth, origHeight;
  
  function updateOriginalDimensions() {
    origWidth = parseFloat(img.getAttribute('data-original-width'));
    origHeight = parseFloat(img.getAttribute('data-original-height'));
    console.log("📐 Original dimensions:", origWidth, "x", origHeight);
  }
  
  // Get the actual rendered image position and size
  function getRenderedImageBounds() {
    const imgRect = img.getBoundingClientRect();
    const wrapperRect = wrapper.getBoundingClientRect();
    
    // Calculate the rendered image dimensions (accounting for object-fit:contain)
    const imgAspect = origWidth / origHeight;
    const wrapperAspect = wrapperRect.width / wrapperRect.height;
    
    let renderedWidth, renderedHeight;
    let offsetLeft, offsetTop;
    
    if (imgAspect > wrapperAspect) {
      // Image is wider - limited by wrapper width
      renderedWidth = wrapperRect.width;
      renderedHeight = renderedWidth / imgAspect;
      offsetLeft = 0;
      offsetTop = (wrapperRect.height - renderedHeight) / 2;
    } else {
      // Image is taller - limited by wrapper height
      renderedHeight = wrapperRect.height;
      renderedWidth = renderedHeight * imgAspect;
      offsetTop = 0;
      offsetLeft = (wrapperRect.width - renderedWidth) / 2;
    }
    
    return {
      left: offsetLeft,
      top: offsetTop,
      width: renderedWidth,
      height: renderedHeight,
      wrapperWidth: wrapperRect.width,
      wrapperHeight: wrapperRect.height
    };
  }

  // Update line positions based on boundary values
  function updateLinePositions() {
    if (!origWidth || !origHeight) {
      updateOriginalDimensions();
    }
    
    const bounds = getRenderedImageBounds();
    
    console.log("🖼️ Rendered image bounds:", {
      offset: `${bounds.left}px, ${bounds.top}px`,
      size: `${bounds.width}px x ${bounds.height}px`,
      wrapper: `${bounds.wrapperWidth}px x ${bounds.wrapperHeight}px`
    });

    // Update horizontal lines
    wrapper.querySelectorAll('.draggable-line.horizontal-line').forEach(line => {
      const boundaryValue = parseFloat(line.getAttribute('data-boundary-value') || 0);
      
      // Convert: original Y coord → % of original height → rendered pixel position → wrapper position
      const percentOfOriginal = boundaryValue / origHeight;
      const posInRenderedImage = percentOfOriginal * bounds.height;
      const finalPos = bounds.top + posInRenderedImage;
      
      line.style.top = `${finalPos}px`;
      line.style.left = `${bounds.left}px`;
      line.style.width = `${bounds.width}px`;
      
      console.log(`🔴 H-line ${line.getAttribute('data-line-index')}: boundary=${boundaryValue}, %=${(percentOfOriginal*100).toFixed(2)}%, rendered=${posInRenderedImage.toFixed(2)}px, final=${finalPos.toFixed(2)}px`);
    });

    // Update vertical lines
    wrapper.querySelectorAll('.draggable-line.vertical-line').forEach(line => {
      const boundaryValue = parseFloat(line.getAttribute('data-boundary-value') || 0);
      
      // Convert: original X coord → % of original width → rendered pixel position → wrapper position
      const percentOfOriginal = boundaryValue / origWidth;
      const posInRenderedImage = percentOfOriginal * bounds.width;
      const finalPos = bounds.left + posInRenderedImage;
      
      line.style.left = `${finalPos}px`;
      line.style.top = `${bounds.top}px`;
      line.style.height = `${bounds.height}px`;
      
      console.log(`🔵 V-line ${line.getAttribute('data-line-index')}: boundary=${boundaryValue}, %=${(percentOfOriginal*100).toFixed(2)}%, rendered=${posInRenderedImage.toFixed(2)}px, final=${finalPos.toFixed(2)}px`);
    });
  }

  // Initial positioning after image loads
  if (img.complete && img.naturalWidth > 0) {
    updateOriginalDimensions();
    updateLinePositions();
  }
  
  img.addEventListener('load', () => {
    console.log("✅ Image loaded successfully");
    updateOriginalDimensions();
    updateLinePositions();
  });
  
  // Reposition on window resize (debounced)
  let resizeTimeout;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(() => {
      console.log("🔄 Window resized - updating line positions");
      updateLinePositions();
    }, 100);
  });

  // Setup drag handlers
  wrapper.querySelectorAll('.draggable-line.horizontal-line').forEach(line => {
    Object.assign(line.style, {
      position: 'absolute',
      height: '4px',
      cursor: 'row-resize',
      pointerEvents: 'all',
      zIndex: '1000',
      backgroundColor: 'rgba(255, 0, 0, 0.6)',
      boxShadow: '0 0 3px rgba(0,0,0,0.3)'
    });
    attachDrag(line, 'H', wrapper, prefix, img, updateLinePositions);
  });

  wrapper.querySelectorAll('.draggable-line.vertical-line').forEach(line => {
    Object.assign(line.style, {
      position: 'absolute',
      width: '4px',
      cursor: 'col-resize',
      pointerEvents: 'all',
      zIndex: '1000',
      backgroundColor: 'rgba(0, 0, 255, 0.6)',
      boxShadow: '0 0 3px rgba(0,0,0,0.3)'
    });
    attachDrag(line, 'V', wrapper, prefix, img, updateLinePositions);
  });
}

function attachDrag(line, axis, wrapper, prefix, img, updateLinePositions) {
  let startCursorPos, startLinePos, bounds, origWidth, origHeight;

  line.addEventListener('mousedown', e => {
    e.preventDefault();
    
    // Get fresh measurements at drag start
    origWidth = parseFloat(img.getAttribute('data-original-width'));
    origHeight = parseFloat(img.getAttribute('data-original-height'));
    
    // Calculate rendered image bounds
    const imgRect = img.getBoundingClientRect();
    const wrapperRect = wrapper.getBoundingClientRect();
    const imgAspect = origWidth / origHeight;
    const wrapperAspect = wrapperRect.width / wrapperRect.height;
    
    let renderedWidth, renderedHeight, offsetLeft, offsetTop;
    
    if (imgAspect > wrapperAspect) {
      renderedWidth = wrapperRect.width;
      renderedHeight = renderedWidth / imgAspect;
      offsetLeft = 0;
      offsetTop = (wrapperRect.height - renderedHeight) / 2;
    } else {
      renderedHeight = wrapperRect.height;
      renderedWidth = renderedHeight * imgAspect;
      offsetTop = 0;
      offsetLeft = (wrapperRect.width - renderedWidth) / 2;
    }
    
    bounds = {
      left: offsetLeft,
      top: offsetTop,
      width: renderedWidth,
      height: renderedHeight
    };

    console.log("🖱️ Drag started", axis === 'H' ? 'horizontal' : 'vertical', "line", line.getAttribute('data-line-index'));
    console.log("   Rendered bounds:", bounds);

    if (axis === 'H') {
      startCursorPos = e.clientY;
      startLinePos = parseFloat(line.style.top);
    } else {
      startCursorPos = e.clientX;
      startLinePos = parseFloat(line.style.left);
    }

    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp, { once: true });
  });

  function onMove(e) {
    if (axis === 'H') {
      const delta = e.clientY - startCursorPos;
      let newPos = startLinePos + delta;
      // Constrain within rendered image bounds
      newPos = Math.max(bounds.top, Math.min(newPos, bounds.top + bounds.height));
      line.style.top = `${newPos}px`;
    } else {
      const delta = e.clientX - startCursorPos;
      let newPos = startLinePos + delta;
      newPos = Math.max(bounds.left, Math.min(newPos, bounds.left + bounds.width));
      line.style.left = `${newPos}px`;
    }
  }

  function onUp() {
    const idx = line.getAttribute('data-line-index');

    if (axis === 'H') {
      // Convert wrapper pixel position back to original image coordinates
      const wrapperPos = parseFloat(line.style.top);
      const posInRenderedImage = wrapperPos - bounds.top;
      const percentOfRendered = posInRenderedImage / bounds.height;
      const originalCoord = Math.round(percentOfRendered * origHeight);
      
      // Store boundary value for future repositioning
      line.setAttribute('data-boundary-value', originalCoord);
      
      const payload = {
        id: idx,
        pos_px_wrapper: posInRenderedImage,  // Position within rendered image
        wrapper_dim: bounds.height           // Rendered image height
      };
      
      console.log(`📤 H line ${idx}:`, {
        wrapperPos: wrapperPos.toFixed(2),
        renderedPos: posInRenderedImage.toFixed(2),
        percent: (percentOfRendered * 100).toFixed(2),
        originalCoord
      });
      
      Shiny.setInputValue(`${prefix}-hline_moved_direct`, payload, { priority: 'event' });
    } else {
      const wrapperPos = parseFloat(line.style.left);
      const posInRenderedImage = wrapperPos - bounds.left;
      const percentOfRendered = posInRenderedImage / bounds.width;
      const originalCoord = Math.round(percentOfRendered * origWidth);
      
      line.setAttribute('data-boundary-value', originalCoord);
      
      const payload = {
        id: idx,
        pos_px_wrapper: posInRenderedImage,  // Position within rendered image
        wrapper_dim: bounds.width            // Rendered image width
      };
      
      console.log(`📤 V line ${idx}:`, {
        wrapperPos: wrapperPos.toFixed(2),
        renderedPos: posInRenderedImage.toFixed(2),
        percent: (percentOfRendered * 100).toFixed(2),
        originalCoord
      });
      
      Shiny.setInputValue(`${prefix}-vline_moved_direct`, payload, { priority: 'event' });
    }
    
    document.removeEventListener('mousemove', onMove);
  }
}
