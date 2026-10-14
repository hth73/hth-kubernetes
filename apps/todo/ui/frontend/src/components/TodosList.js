import React from "react";
import TodoItem from "./TodoItem";

function TodosList({todos, updateTodoProps, deleteTodoProps}) {
    return (
        <ul className="todo-list">
            {todos.map(todo => (
                <TodoItem
                    key={todo.id}
                    todo={todo}
                    updateTodoProps={updateTodoProps}
                    deleteTodoProps={deleteTodoProps}
                />
            ))}
        </ul>
    );
}

export default TodosList