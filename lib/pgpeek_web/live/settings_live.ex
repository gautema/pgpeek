defmodule PgpeekWeb.SettingsLive do
  use PgpeekWeb, :live_view

  alias Pgpeek.Auth

  @impl true
  def mount(_params, _session, socket) do
    users = Auth.list_users()

    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:users, users)
      |> assign(:password_form, to_form(%{"password" => "", "password_confirmation" => ""}, as: :password))
      |> assign(:password_saved, false)
      |> assign(:new_user_form, to_form(%{"email" => "", "password" => ""}, as: :user))
      |> assign(:new_user_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("change_password", %{"password" => params}, socket) do
    password = params["password"]
    confirmation = params["password_confirmation"]

    cond do
      password != confirmation ->
        {:noreply,
         socket
         |> assign(:password_saved, false)
         |> put_flash(:error, "Passwords do not match")}

      String.length(password) < 8 ->
        {:noreply,
         socket
         |> assign(:password_saved, false)
         |> put_flash(:error, "Password must be at least 8 characters")}

      true ->
        case Auth.change_password(socket.assigns.current_user, %{password: password}) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> assign(:password_saved, true)
             |> assign(:password_form, to_form(%{"password" => "", "password_confirmation" => ""}, as: :password))
             |> put_flash(:info, "Password updated successfully")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update password")}
        end
    end
  end

  @impl true
  def handle_event("create_user", %{"user" => params}, socket) do
    case Auth.create_user(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:users, Auth.list_users())
         |> assign(:new_user_form, to_form(%{"email" => "", "password" => ""}, as: :user))
         |> assign(:new_user_error, nil)
         |> put_flash(:info, "User created")}

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        error_msg =
          errors
          |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
          |> Enum.join("; ")

        {:noreply, assign(socket, :new_user_error, error_msg)}
    end
  end

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Auth.get_user!(String.to_integer(id))

    if user.id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account")}
    else
      Auth.delete_user(user)

      {:noreply,
       socket
       |> assign(:users, Auth.list_users())
       |> put_flash(:info, "User deleted")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-bold text-white">Settings</h1>
          <p class="mt-1 text-sm text-slate-400">Manage your account and users</p>
        </div>

        <%!-- Change Password --%>
        <div class="glass-card overflow-hidden">
          <div class="flex items-center gap-2 px-6 py-4 border-b border-white/5">
            <.icon name="hero-key" class="size-5 text-slate-500" />
            <h2 class="text-base font-semibold text-white">Change Password</h2>
          </div>
          <div class="p-6">
            <.form for={@password_form} phx-submit="change_password" id="password-form" class="max-w-sm space-y-4">
              <div>
                <label for="password-field" class="block text-sm font-medium text-slate-400 mb-1.5">New Password</label>
                <input
                  type="password"
                  name="password[password]"
                  id="password-field"
                  required
                  minlength="8"
                  autocomplete="new-password"
                  class="w-full rounded-lg border border-white/10 bg-white/5 px-3.5 py-2.5 text-sm text-white placeholder-slate-500 focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 focus:outline-none transition-colors"
                  placeholder="Minimum 8 characters"
                />
              </div>
              <div>
                <label for="password-confirm" class="block text-sm font-medium text-slate-400 mb-1.5">Confirm Password</label>
                <input
                  type="password"
                  name="password[password_confirmation]"
                  id="password-confirm"
                  required
                  autocomplete="new-password"
                  class="w-full rounded-lg border border-white/10 bg-white/5 px-3.5 py-2.5 text-sm text-white placeholder-slate-500 focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 focus:outline-none transition-colors"
                  placeholder="Repeat password"
                />
              </div>
              <button
                type="submit"
                class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-500 transition-colors cursor-pointer"
              >
                Update Password
              </button>
            </.form>
          </div>
        </div>

        <%!-- User Management --%>
        <div class="glass-card overflow-hidden">
          <div class="flex items-center gap-2 px-6 py-4 border-b border-white/5">
            <.icon name="hero-users" class="size-5 text-slate-500" />
            <h2 class="text-base font-semibold text-white">Users</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="border-b border-white/5">
                  <th class="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">Email</th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">Created</th>
                  <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider text-slate-500">Last Login</th>
                  <th class="px-4 py-3 text-right text-xs font-medium uppercase tracking-wider text-slate-500"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-white/5">
                <%= for user <- @users do %>
                  <tr class="hover:bg-white/[0.02] transition-colors">
                    <td class="px-6 py-3 text-sm text-slate-300">
                      {user.email}
                      <%= if user.id == @current_user.id do %>
                        <span class="ml-2 inline-flex items-center rounded-full bg-blue-500/10 px-2 py-0.5 text-xs font-medium text-blue-400">you</span>
                      <% end %>
                    </td>
                    <td class="px-4 py-3 text-sm text-slate-500">
                      <%= if user.inserted_at, do: Calendar.strftime(user.inserted_at, "%Y-%m-%d"), else: "-" %>
                    </td>
                    <td class="px-4 py-3 text-sm text-slate-500">
                      <%= if user.last_login_at, do: Calendar.strftime(user.last_login_at, "%Y-%m-%d %H:%M"), else: "Never" %>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <%= if user.id != @current_user.id do %>
                        <button
                          phx-click="delete_user"
                          phx-value-id={user.id}
                          data-confirm="Are you sure you want to delete this user?"
                          class="text-xs text-red-400 hover:text-red-300 transition-colors cursor-pointer"
                        >
                          Delete
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%!-- Add User Form --%>
          <div class="border-t border-white/5 px-6 py-4">
            <h3 class="text-sm font-medium text-slate-400 mb-3">Add User</h3>
            <%= if @new_user_error do %>
              <div class="mb-3 rounded-lg bg-red-500/10 border border-red-500/20 px-3 py-2">
                <p class="text-xs text-red-400">{@new_user_error}</p>
              </div>
            <% end %>
            <.form for={@new_user_form} phx-submit="create_user" id="new-user-form" class="flex items-end gap-3">
              <div class="flex-1">
                <label for="new-email" class="block text-xs font-medium text-slate-500 mb-1">Email</label>
                <input
                  type="email"
                  name="user[email]"
                  id="new-email"
                  required
                  class="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 focus:outline-none transition-colors"
                  placeholder="user@example.com"
                />
              </div>
              <div class="flex-1">
                <label for="new-password" class="block text-xs font-medium text-slate-500 mb-1">Password</label>
                <input
                  type="password"
                  name="user[password]"
                  id="new-password"
                  required
                  minlength="8"
                  class="w-full rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500/50 focus:ring-1 focus:ring-blue-500/50 focus:outline-none transition-colors"
                  placeholder="Min 8 characters"
                />
              </div>
              <button
                type="submit"
                class="rounded-lg bg-white/5 border border-white/10 px-4 py-2 text-sm font-medium text-slate-300 hover:bg-white/10 transition-colors cursor-pointer"
              >
                Add
              </button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
