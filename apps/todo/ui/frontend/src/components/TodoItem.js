import React from "react";

class TodoItem extends React.Component {
    state = {
        isEditing: false,
        isSaving: false,
        isConfirmingDelete: false,
        title: this.props.todo.title,
    };

    startEditing = () => {
        this.setState({isEditing: true, title: this.props.todo.title});
    };

    cancelEditing = () => {
        this.setState({isEditing: false, title: this.props.todo.title});
    };

    saveTitle = async event => {
        event.preventDefault();
        const title = this.state.title.trim();
        if (!title || this.state.isSaving) {
            return;
        }

        this.setState({isSaving: true});
        const saved = await this.props.updateTodoProps(this.props.todo.id, {title});
        this.setState({isSaving: false, isEditing: !saved});
    };

    toggleChecked = () => {
        this.props.updateTodoProps(this.props.todo.id, {
            checked: !this.props.todo.checked,
        });
    };

    deleteTodo = async () => {
        const deleted = await this.props.deleteTodoProps(this.props.todo.id);
        if (!deleted) {
            this.setState({isConfirmingDelete: false});
        }
    };

    render() {
        const {todo} = this.props;

        return (
            <li className={`todo-item${todo.checked ? " is-completed" : ""}`}>
                <input
                    className="todo-checkbox"
                    type="checkbox"
                    checked={todo.checked}
                    onChange={this.toggleChecked}
                    aria-label={`Mark "${todo.title}" ${todo.checked ? "as open" : "as completed"}`}
                />
                {this.state.isEditing ? (
                    <form className="edit-form" onSubmit={this.saveTitle}>
                        <label className="sr-only" htmlFor={`edit-task-${todo.id}`}>Edit task</label>
                        <input
                            id={`edit-task-${todo.id}`}
                            type="text"
                            value={this.state.title}
                            onChange={event => this.setState({title: event.target.value})}
                            maxLength={255}
                            required
                            autoFocus
                        />
                        <button type="submit" disabled={!this.state.title.trim() || this.state.isSaving}>
                            Save
                        </button>
                        <button type="button" className="secondary-button" onClick={this.cancelEditing}>
                            Cancel
                        </button>
                    </form>
                ) : (
                    <>
                        <span className="todo-title">{todo.title}</span>
                        <div className="todo-actions">
                            {this.state.isConfirmingDelete ? (
                                <>
                                    <span className="confirm-label">Delete?</span>
                                    <button type="button" className="text-button" onClick={this.deleteTodo}>
                                        Confirm
                                    </button>
                                    <button
                                        type="button"
                                        className="text-button"
                                        onClick={() => this.setState({isConfirmingDelete: false})}
                                    >
                                        Keep
                                    </button>
                                </>
                            ) : (
                                <>
                                    <button
                                        type="button"
                                        className="text-button"
                                        onClick={this.startEditing}
                                        aria-label={`Edit "${todo.title}"`}
                                    >
                                        Edit
                                    </button>
                                    <button
                                        type="button"
                                        className="text-button delete-button"
                                        onClick={() => this.setState({isConfirmingDelete: true})}
                                        aria-label={`Delete "${todo.title}"`}
                                    >
                                        Delete
                                    </button>
                                </>
                            )}
                        </div>
                    </>
                )}
            </li>
        );
    }
}

export default TodoItem