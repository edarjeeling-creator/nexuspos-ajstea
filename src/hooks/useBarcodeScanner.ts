'use client'

import { useEffect, useRef, useCallback } from 'react';

interface UseBarcodeScannerProps {
  onScan: (barcode: string) => void;
  timeout?: number; // ms to clear buffer
}

export function useBarcodeScanner({ onScan, timeout = 50 }: UseBarcodeScannerProps) {
  const buffer = useRef('');
  const lastKeyTime = useRef(0);

  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    // Ignore if user is typing in an input field natively
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes((e.target as HTMLElement).tagName)) {
      return;
    }

    const currentTime = Date.now();
    const elapsedTime = currentTime - lastKeyTime.current;

    // A fast series of keystrokes indicates a scanner.
    // If it's too slow (> timeout), it's probably a human typing, so reset the buffer.
    if (elapsedTime > timeout) {
      buffer.current = ''; 
    }

    lastKeyTime.current = currentTime;

    if (e.key === 'Enter') {
      if (buffer.current.length > 3) {
        // Most barcodes are at least 4 chars. Fire scan event.
        onScan(buffer.current);
        e.preventDefault(); 
      }
      buffer.current = '';
    } else if (e.key.length === 1) {
      // Printable characters
      buffer.current += e.key;
    }
  }, [onScan, timeout]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [handleKeyDown]);
}
