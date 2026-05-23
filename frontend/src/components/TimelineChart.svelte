<script>
  import { onMount } from 'svelte';
  import { Chart, registerables } from 'chart.js';

  Chart.register(...registerables);

  export let items = [];

  let canvas;
  let chart;

  onMount(() => {
    renderChart();
    return () => chart?.destroy();
  });

  $: if (chart && items) {
    updateChart();
  }

  function renderChart() {
    const ctx = canvas.getContext('2d');

    // Group by hour for visualization
    const hourCounts = Array(24).fill(0);
    items.forEach(item => {
      const hour = parseInt(item.time.split(':')[0]);
      hourCounts[hour]++;
    });

    chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: Array.from({ length: 24 }, (_, i) => `${i}h`),
        datasets: [{
          label: 'Nombre de réveils',
          data: hourCounts,
          backgroundColor: 'rgba(0, 113, 227, 0.8)',
          borderColor: 'rgba(0, 113, 227, 1)',
          borderWidth: 1,
          borderRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          title: {
            display: true,
            text: 'Distribution des réveils par heure',
            font: {
              family: '-apple-system, BlinkMacSystemFont, "SF Pro Display"',
              size: 16,
              weight: '600'
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              stepSize: 1,
              font: {
                family: '-apple-system, BlinkMacSystemFont, "SF Pro Text"'
              }
            },
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: {
            ticks: {
              font: {
                family: '-apple-system, BlinkMacSystemFont, "SF Pro Text"'
              }
            },
            grid: {
              display: false
            }
          }
        }
      }
    });
  }

  function updateChart() {
    const hourCounts = Array(24).fill(0);
    items.forEach(item => {
      const hour = parseInt(item.time.split(':')[0]);
      hourCounts[hour]++;
    });

    chart.data.datasets[0].data = hourCounts;
    chart.update();
  }
</script>

<div class="h-64">
  <canvas bind:this={canvas}></canvas>
</div>
