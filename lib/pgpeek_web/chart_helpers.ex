defmodule PgpeekWeb.ChartHelpers do
  @moduledoc "Helpers for building Chart.js configurations from Elixir data."

  @doc "Build a line chart config for query history deltas (avg time + calls per period)."
  def query_history_chart(history) do
    # History comes newest-first, reverse for chronological order
    points = Enum.reverse(history)

    labels =
      Enum.map(points, fn h ->
        Calendar.strftime(h.captured_at, "%m/%d %H:%M")
      end)

    mean_times = Enum.map(points, fn h -> h.delta_mean_time end)
    calls = Enum.map(points, fn h -> h.delta_calls end)

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Avg Time per Call (ms)",
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
            label: "Calls per Period",
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
    # Data already comes in chronological order (oldest first)
    points = snapshot_data

    labels = Enum.map(points, fn {time, _val} -> Calendar.strftime(time, "%H:%M") end)
    values = Enum.map(points, fn {_time, val} -> val end)

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [
          %{
            label: "Query Time Added (s)",
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

  @doc "Build multiple small system stat charts from trend data."
  def system_charts(trend) when length(trend) < 2, do: []

  def system_charts(trend) do
    labels = Enum.map(trend, fn t -> Calendar.strftime(t.captured_at, "%H:%M") end)

    charts = [
      build_system_chart("Connections", labels, trend, [
        dataset("Active", & &1.active_connections, "rgb(96, 165, 250)"),
        dataset("Idle in TX", & &1.idle_in_transaction, "rgb(251, 191, 36)")
      ]),
      build_system_chart("Cache Hit %", labels, trend, [
        dataset("Hit Ratio", & &1.cache_hit_ratio, "rgb(52, 211, 153)")
      ]),
      build_system_chart("Replication Lag", labels, trend, [
        dataset("Bytes", & &1.replication_lag_bytes, "rgb(244, 114, 182)")
      ]),
      build_system_chart("TX Wraparound Age", labels, trend, [
        dataset("Age", & &1.tx_wraparound_age, "rgb(251, 146, 60)")
      ]),
      build_system_chart("Temp Bytes", labels, trend, [
        dataset("Bytes", & &1.temp_bytes, "rgb(167, 139, 250)")
      ]),
      build_system_chart("Database Size", labels, trend, [
        dataset(
          "Bytes",
          fn t -> (t.database_size_bytes || 0) / 1_048_576.0 end,
          "rgb(45, 212, 191)"
        )
      ])
    ]

    # Only include charts that have non-nil data
    Enum.filter(charts, fn {_title, config} ->
      config.data.datasets
      |> Enum.any?(fn ds -> Enum.any?(ds.data, &(not is_nil(&1) and &1 != 0)) end)
    end)
  end

  defp build_system_chart(title, labels, trend, datasets) do
    {title,
     %{
       type: "line",
       data: %{
         labels: labels,
         datasets:
           Enum.map(datasets, fn {label, extractor, color} ->
             bg =
               color
               |> String.replace("rgb(", "rgba(")
               |> String.replace(")", ", 0.08)")

             %{
               label: label,
               data: Enum.map(trend, extractor),
               borderColor: color,
               backgroundColor: bg,
               borderWidth: 1.5,
               pointRadius: 0,
               pointHitRadius: 8,
               fill: true,
               tension: 0.3
             }
           end)
       },
       options: chart_options_single("")
     }}
  end

  defp dataset(label, extractor, color), do: {label, extractor, color}

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
