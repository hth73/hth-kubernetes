import React from "react";
import TodosList from "./TodosList";
import Header from "./Header";
import InputTodo from "./InputTodo";

function getApiBaseUrl() {
    const configuredUrl = window._env_?.REACT_APP_BACKEND_BASE_URI;
    if (!configuredUrl) {
        throw new Error("The backend URL is not configured.");
    }

    return new URL(configuredUrl, window.location.origin).toString().replace(/\/?$/, "/");
}

class TodoContainer extends React.Component {
    state = {
        todos: [],
        isLoading: true,
        error: "",
        searchQuery: "",
        filter: "all",
    };

    componentDidMount() {
        this.loadTodos();
    }

    request = async (path, options = {}) => {
        let response;
        try {
            response = await fetch(new URL(path, getApiBaseUrl()), options);
        } catch {
            throw new Error("Could not connect to the backend. Check your connection and try again.");
        }

        const responseBody = await response.text();
        let data = null;
        if (responseBody.trim()) {
            try {
                data = JSON.parse(responseBody);
            } catch {
                if (response.ok) {
                    throw new Error("The backend returned an invalid response.");
                }
            }
        }

        if (!response.ok) {
            const detail = data && typeof data.detail === "string" ? ` ${data.detail}` : "";
            throw new Error(`The backend request failed (HTTP ${response.status}).${detail}`);
        }

        return data;
    };

    loadTodos = async () => {
        this.setState({isLoading: true, error: ""});
        try {
            const todos = await this.request("");
            if (todos !== null && !Array.isArray(todos)) {
                throw new Error("The backend returned an invalid task list.");
            }
            this.setState({todos: todos || []});
        } catch (error) {
            this.setState({error: error.message});
        } finally {
            this.setState({isLoading: false});
        }
    };

    saveTodo = async (title) => {
        try {
            const todo = await this.request("", {
                method: "POST",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify({title, checked: false}),
            });
            if (todo === null) {
                await this.loadTodos();
                return true;
            }
            this.setState(previousState => ({
                todos: [...previousState.todos, todo],
                error: "",
            }));
            return true;
        } catch (error) {
            this.setState({error: `Could not add the task. ${error.message}`});
            return false;
        }
    };

    updateTodo = async (id, changes) => {
        try {
            const todo = await this.request(String(id), {
                method: "PUT",
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify(changes),
            });
            this.setState(previousState => ({
                todos: previousState.todos.map(item => item.id === id
                    ? {...item, ...changes, ...(todo || {})}
                    : item),
                error: "",
            }));
            return true;
        } catch (error) {
            this.setState({error: `Could not update the task. ${error.message}`});
            return false;
        }
    };

    deleteTodo = async (id) => {
        try {
            await this.request(String(id), {method: "DELETE"});
            this.setState(previousState => ({
                todos: previousState.todos.filter(todo => todo.id !== id),
                error: "",
            }));
            return true;
        } catch (error) {
            this.setState({error: `Could not delete the task. ${error.message}`});
            return false;
        }
    };

    setSearchQuery = (event) => {
        this.setState({searchQuery: event.target.value});
    };

    setFilter = (filter) => {
        this.setState({filter});
    };

    render() {
        const {todos, isLoading, error, searchQuery, filter} = this.state;
        const visibleTodos = todos.filter(todo => {
            const matchesSearch = todo.title.toLowerCase().includes(searchQuery.trim().toLowerCase());
            const matchesFilter = filter === "all"
                || (filter === "open" && !todo.checked)
                || (filter === "completed" && todo.checked);
            return matchesSearch && matchesFilter;
        });
        const openCount = todos.filter(todo => !todo.checked).length;

        return (
            <main className="todo-app">
                <Header/>
                <section aria-label="Tasks">
                    <InputTodo addTodoProps={this.saveTodo}/>

                    <div className="todo-toolbar">
                        <label className="search-field">
                            <span className="sr-only">Search tasks</span>
                            <input
                                type="search"
                                placeholder="Search tasks"
                                value={searchQuery}
                                onChange={this.setSearchQuery}
                            />
                        </label>
                        <div className="filter-list" role="group" aria-label="Filter tasks">
                            {[
                                ["all", "All"],
                                ["open", "Open"],
                                ["completed", "Completed"],
                            ].map(([value, label]) => (
                                <button
                                    key={value}
                                    type="button"
                                    className={`filter-button${filter === value ? " is-active" : ""}`}
                                    aria-pressed={filter === value}
                                    onClick={() => this.setFilter(value)}
                                >
                                    {label}
                                </button>
                            ))}
                        </div>
                    </div>

                    <p className="task-count" aria-live="polite">
                        {openCount} {openCount === 1 ? "task" : "tasks"} left
                    </p>

                    {error && (
                        <div className="error-message" role="alert">
                            <span>{error}</span>
                            <button type="button" className="text-button" onClick={this.loadTodos}>
                                Retry
                            </button>
                        </div>
                    )}
                    {isLoading ? (
                        <p className="empty-state" role="status">Loading tasks…</p>
                    ) : visibleTodos.length > 0 ? (
                        <TodosList
                            todos={visibleTodos}
                            updateTodoProps={this.updateTodo}
                            deleteTodoProps={this.deleteTodo}
                        />
                    ) : (
                        <p className="empty-state">
                            {todos.length === 0
                                ? "No tasks yet. Add your first task above."
                                : "No tasks match your search or filter."}
                        </p>
                    )}
                </section>
            </main>
        );
    }
}

export default TodoContainer;
