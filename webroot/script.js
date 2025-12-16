const MODDIR = "/data/adb/modules/cache_cleaner";
const CONFIG_FILE = `${MODDIR}/config.conf`;
const LOG_FILE = "/sdcard/Android/cache_cleaner/logs.txt";
const STATS_FILE = "/sdcard/Android/cache_cleaner/stats.json";
const ACTION_LOG = "/sdcard/Android/cache_cleaner/action.log";
const DISABLE_FILE = "/sdcard/Android/cache_cleaner/disable";

let isDark = false;
let autoEnabled = true; // Track state globally

function isMMRL() {
  return navigator.userAgent.includes("com.dergoogler.mmrl");
}

function runShell(command) {
  return new Promise((resolve, reject) => {
    // KernelSU
    if (typeof ksu === "object" && typeof ksu.exec === "function") {
      const cb = `cb_${Date.now()}`;
      window[cb] = (code, stdout, stderr) => {
        delete window[cb];
        code === 0 ? resolve(stdout || stderr) : reject(stderr || "Shell error");
      };
      ksu.exec(command, "{}", cb);
      return;
    }

    // MMRL
    if (isMMRL() && typeof window.execShell === "function") {
      window.execShell(command)
        .then(resolve)
        .catch(err => reject(err || "Shell error"));
      return;
    }

    // Magisk fallback
    fetch(`/shell?method=exec&cmd=${encodeURIComponent(command)}`)
      .then(r => r.text())
      .then(resolve)
      .catch(reject);
  });
}

// Log directly to terminal instead of popup
function logToTerminal(text) {
  const logs = document.getElementById('logs');
  const entry = document.createElement('pre');
  entry.textContent = `[${new Date().toLocaleTimeString()}] ${text}`;
  logs.appendChild(entry);
  logs.scrollTop = logs.scrollHeight;
}

// Check auto-clean status on load
async function checkAutoStatus() {
  try {
    const exists = await runShell(`[ -f ${DISABLE_FILE} ] && echo "disabled" || echo "enabled"`);
    autoEnabled = exists.trim() === 'enabled';
    updateToggleButton();
  } catch (e) {
    console.error("Error checking auto status:", e);
  }
}

function updateToggleButton() {
  const toggleBtn = document.getElementById('toggleBtn');
  if (autoEnabled) {
    toggleBtn.textContent = '⏸️ Disable Auto';
    toggleBtn.className = 'btn secondary';
  } else {
    toggleBtn.textContent = '▶️ Enable Auto';
    toggleBtn.className = 'btn primary';
  }
}

function showFeedback(message, type = 'info') {
  const feedbackEl = document.getElementById('actionFeedback');
  feedbackEl.textContent = message;
  feedbackEl.className = `feedback-card ${type}`;
  feedbackEl.style.display = 'block';
  setTimeout(() => {
    feedbackEl.style.display = 'none';
  }, 5000);
}

function updateStatus() {
  const cmd = `du -cs /data/data/*/cache/* /data/data/*/code_cache/* /data/user_de/*/*/cache/* /data/user_de/*/*/code_cache/* /sdcard/Android/data/*/cache/* 2>/dev/null | tail -1 | cut -f1`;
  
  runShell(cmd).then(size => {
    const mb = Math.floor(parseInt(size || 0) / 1024);
    const threshold = document.getElementById('threshold')?.value || 1024;
    
    document.getElementById('status').innerHTML = `
      💾 Total Cache: <strong>${mb} MB</strong> | 
      🎯 Threshold: <strong>${threshold} MB</strong> | 
      <span class="${mb > threshold ? 'warning' : 'good'}">
        ${mb > threshold ? '⚠️ Exceeds threshold!' : '✅ Within limit'}
      </span>
    `;
  }).catch(err => {
    logToTerminal(`Error checking status: ${err}`);
  });
}

function updateStats() {
  runShell(`cat ${STATS_FILE}`).then(data => {
    const stats = JSON.parse(data || '{}');
    document.getElementById('stats').innerHTML = `
      <div>🕐 Last Clean: <strong>${stats.last_clean || 'Never'}</strong></div>
      <div>📁 Files Deleted: <strong>${stats.files_deleted || 0}</strong></div>
      <div>💾 MB Freed: <strong>${stats.size_freed_mb || 0}</strong></div>
    `;
  }).catch(() => {
    // Stats file might not exist yet
  });
}

function updateLogs() {
  runShell(`tail -30 ${LOG_FILE}`).then(logs => {
    document.getElementById('logs').textContent = logs || 'No logs yet...';
  }).catch(() => {
    document.getElementById('logs').textContent = 'No logs yet...';
  });
}

function loadSettings() {
  runShell(`grep THRESHOLD_MB ${CONFIG_FILE} | cut -d= -f2`).then(val => {
    document.getElementById('threshold').value = val.trim() || "1024";
  }).catch(() => {
    document.getElementById('threshold').value = "1024";
  });
  
  runShell(`echo $(( $(grep CHECK_INTERVAL ${CONFIG_FILE} | cut -d= -f2) / 60 ))`).then(val => {
    document.getElementById('interval').value = val.trim() || "60";
  }).catch(() => {
    document.getElementById('interval').value = "60";
  });
}

// Event Listeners
document.addEventListener("DOMContentLoaded", () => {
  // Theme toggle
  const themeToggle = document.getElementById('theme-toggle');
  const savedTheme = localStorage.getItem('theme');
  
  if (savedTheme === 'dark') {
    document.documentElement.classList.add('dark');
    themeToggle.checked = true;
  }
  
  themeToggle.addEventListener('change', () => {
    if (themeToggle.checked) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
    }
  });

  // Check auto status on load
  checkAutoStatus();

  // Clean Now button - FIXED
  document.getElementById('cleanBtn').addEventListener('click', () => {
    const btn = document.getElementById('cleanBtn');
    btn.disabled = true;
    showFeedback('🚀 Starting cache cleaning...', 'info');
    logToTerminal('Cleaning started...');
    
    // Clear action log and execute
    runShell(`> ${ACTION_LOG}`).then(() => {
      runShell(`sh ${MODDIR}/action.sh`).then(output => {
        logToTerminal('Action script executed');
        setTimeout(() => {
          updateStatus();
          updateStats();
          updateLogs();
          btn.disabled = false;
        }, 3000);
      }).catch(err => {
        logToTerminal(`Error: ${err}`);
        btn.disabled = false;
      });
    });
  });

  // Save Settings button
  document.getElementById('saveBtn').addEventListener('click', () => {
    const threshold = document.getElementById('threshold').value;
    const interval = document.getElementById('interval').value * 60;
    
    showFeedback('💾 Saving settings...', 'info');
    logToTerminal('Saving settings...');
    
    runShell(`sed -i 's/^THRESHOLD_MB=.*/THRESHOLD_MB=${threshold}/' ${CONFIG_FILE}`).then(() => {
      runShell(`sed -i 's/^CHECK_INTERVAL=.*/CHECK_INTERVAL=${interval}/' ${CONFIG_FILE}`).then(() => {
        showFeedback('✅ Settings saved! Restart service to apply.', 'success');
        logToTerminal('Settings saved successfully');
      });
    });
  });

  // Toggle Auto button - FIXED
  document.getElementById('toggleBtn').addEventListener('click', () => {
    if (autoEnabled) {
      runShell(`touch ${DISABLE_FILE}`).then(() => {
        autoEnabled = false;
        updateToggleButton();
        showFeedback('⏸️ Auto-clean disabled', 'warning');
        logToTerminal('Auto-clean disabled');
      }).catch(err => {
        logToTerminal(`Error disabling: ${err}`);
      });
    } else {
      runShell(`rm -f ${DISABLE_FILE}`).then(() => {
        autoEnabled = true;
        updateToggleButton();
        showFeedback('✅ Auto-clean enabled', 'success');
        logToTerminal('Auto-clean enabled');
      }).catch(err => {
        logToTerminal(`Error enabling: ${err}`);
      });
    }
  });

  // Reset Stats button
  document.getElementById('resetBtn').addEventListener('click', () => {
    if (confirm('Reset all statistics?')) {
      runShell(`echo "{}" > ${STATS_FILE}`).then(() => {
        updateStats();
        showFeedback('🔄 Statistics reset', 'info');
        logToTerminal('Statistics reset');
      });
    }
  });

  // Clear Log button
  document.getElementById('clear-log').addEventListener('click', () => {
    runShell(`> ${LOG_FILE}`).then(() => {
      updateLogs();
      logToTerminal('Log cleared');
    });
  });

  // Initial load
  updateStatus();
  updateStats();
  updateLogs();
  
  // Auto-refresh
  setInterval(updateStatus, 5000);
  setInterval(updateLogs, 10000);
});
