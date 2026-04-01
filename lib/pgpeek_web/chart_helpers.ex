defmodule PgpeekWeb.ChartHelpers do
  @moduledoc "Helpers for building Chart.js configurations from Elixir data."

  @doc "Build a line chart config for query history (mean time + calls over time)."
  def query_history_chart(history) do
    # History comes newest-first, reverse for chronological order
    points = Enum.reverse(history)

    labels =
      Enum.map(points, fn h ->
        Calendar.strftime(h.captured_at, "%m/%d %H:%M")
      end)

    mean_times = Enum.map(points, fn h -> h.mean_exec_time end)
    calls = Enum.map(points, fn h -> h.calls end)

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Mean Time (ms)",
            data: mean_times,
            borderColor: "rgb(96, 165, 250)",
            backgroundColor: "rgba(96, 165, 250, 0.1)",
            borderWidth: 2,
            pointRadius: 0,
            pointHitRadius: 8,
            fill: true,
            tension: 0.3,
            yAxisID: "y"
          },
          %{
            label: "Calls",
            data: calls,
            borderColor: "rgb(167, 139, 250)",
            backgroundColor: "rgba(167, 139, 250, 0.05)",
            borderWidth: 2,
            pointRadius: 0,
            pointHitRadius: 8,
            fill: true,
            tension: 0.3,
            yAxisID: "y1"
          }
        ]
      },
      options: chart_options_dual_axis("ms", "calls")
    }
  end

  @doc "Build a sparkline-style area chart (no axes, no legend)."
  def sparkline_chart(values, color \\ "rgb(96, 165, 250)") do
    bg_color =
      color
      |> String.replace("rgb(", "rgba(")
      |> String.replace(")", ", 0.15)")

    %{
      type: "line",
      data: %{
        labels: Enum.map(1..length(values), &to_string/1),
        datasets: [
          %{
            data: values,
            borderColor: color,
            backgroundColor: bg_color,
            borderWidth: 1.5,
            pointRadius: 0,
            fill: true,
            tension: 0.4
          }
        ]
      },
      options: %{
        responsive: true,
        maintainAspectRatio: false,
        plugins: %{legend: %{display: false}, tooltip: %{enabled: false}},
        scales: %{
          x: %{display: false},
          y: %{display: false, beginAtZero: true}
        },
        interaction: %{intersect: false},
        animation: %{duration: 0}
      }
    }
  end

  @doc "Build a dashboard overview chart with total time across snapshots."
  def dashboard_trend_chart(snapshot_data) do
    points = Enum.reverse(snapshot_data)

    labels = Enum.map(points, fn {time, _val} -> Calendar.strftime(time, "%H:%M") end)
    values = Enum.map(points, fn {_time, val} -> val end)

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Total Query Time (s)",
            data: values,
            borderColor: "rgb(52, 211, 153)",
            backgroundColor: "rgba(52, 211, 153, 0.08)",
            borderWidth: 2,
            pointRadius: 0,
            pointHitRadius: 8,
            fill: true,
            tension: 0.3
          }
        ]
      },
      options: chart_options_single("s")
    }
  end

  defp chart_options_dual_axis(y_unit, y1_unit) do
    %{
      responsive: true,
      maintainAspectRatio: false,
      interaction: %{mode: "index", intersect: false},
      plugins: %{
        legend: %{
          position: "top",
          labels: %{
            boxWidth: 12,
            boxHeight: 2,
            usePointStyle: false,
            padding: 16
          }
        },
        tooltip: %{
          backgroundColor: "rgba(15, 23, 42, 0.9)",
          borderColor: "rgba(255, 255, 255, 0.1)",
          borderWidth: 1,
          titleFont: %{size: 12},
          bodyFont: %{size: 11},
          padding: 10,
          callbacks: %{}
        }
      },
      scales: %{
        x: %{
          grid: %{color: "rgba(255, 255, 255, 0.03)"},
          ticks: %{maxTicksLimit: 12, maxRotation: 0}
        },
        y: %{
          position: "left",
          grid: %{color: "rgba(255, 255, 255, 0.03)"},
          title: %{display: true, text: y_unit, color: "rgb(148, 163, 184)"},
          beginAtZero: true
        },
        y1: %{
          position: "right",
          grid: %{drawOnChartArea: false},
          title: %{display: true, text: y1_unit, color: "rgb(148, 163, 184)"},
          beginAtZero: true
        }
      },
      animation: %{duration: 300}
    }
  end

  defp chart_options_single(unit) do
    %{
      responsive: true,
      maintainAspectRatio: false,
      interaction: %{mode: "index", intersect: false},
      plugins: %{
        legend: %{display: false},
        tooltip: %{
          backgroundColor: "rgba(15, 23, 42, 0.9)",
          borderColor: "rgba(255, 255, 255, 0.1)",
          borderWidth: 1,
          padding: 10
        }
      },
      scales: %{
        x: %{
          grid: %{color: "rgba(255, 255, 255, 0.03)"},
          ticks: %{maxTicksLimit: 12, maxRotation: 0}
        },
        y: %{
          grid: %{color: "rgba(255, 255, 255, 0.03)"},
          title: %{display: true, text: unit, color: "rgb(148, 163, 184)"},
          beginAtZero: true
        }
      },
      animation: %{duration: 300}
    }
  end
end
