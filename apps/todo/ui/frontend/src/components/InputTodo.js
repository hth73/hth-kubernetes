import React, {Component} from "react";

class InputTodo extends Component {
    state = {
        title: "",
        isSubmitting: false,
    };

    onChange = event => {
        this.setState({title: event.target.value});
    };

    handleSubmit = async event => {
        event.preventDefault();
        const title = this.state.title.trim();
        if (!title || this.state.isSubmitting) {
            return;
        }

        this.setState({isSubmitting: true});
        const saved = await this.props.addTodoProps(title);
        this.setState(previousState => ({
            title: saved ? "" : previousState.title,
            isSubmitting: false,
        }));
    };

    render() {
        return (
            <form className="todo-form" onSubmit={this.handleSubmit}>
                <label className="sr-only" htmlFor="new-task">New task</label>
                <input
                    id="new-task"
                    type="text"
                    placeholder="Add a task"
                    value={this.state.title}
                    onChange={this.onChange}
                    maxLength={255}
                    required
                />
                <button type="submit" disabled={!this.state.title.trim() || this.state.isSubmitting}>
                    {this.state.isSubmitting ? "Adding…" : "Add task"}
                </button>
            </form>
        )
    }
}

export default InputTodo