import React from "react";
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import "@testing-library/jest-dom";
import TodoContainer from "./TodoContainer";

function apiResponse(body, status = 200) {
    return {
        ok: status >= 200 && status < 300,
        status,
        text: async () => body === null ? "" : JSON.stringify(body),
    };
}

beforeEach(() => {
    window._env_ = {REACT_APP_BACKEND_BASE_URI: "/api/items/"};
    global.fetch = jest.fn();
});

afterEach(() => {
    jest.resetAllMocks();
});

test("uses the persistent API for creating, editing, completing, and deleting tasks", async () => {
    global.fetch
        .mockResolvedValueOnce(apiResponse([{id: 1, title: "Plan", checked: false}]))
        .mockResolvedValueOnce(apiResponse({id: 2, title: "Write tests", checked: false}))
        .mockResolvedValueOnce(apiResponse({id: 1, title: "Plan week", checked: false}))
        .mockResolvedValueOnce(apiResponse({id: 1, title: "Plan week", checked: true}))
        .mockResolvedValueOnce(apiResponse(null, 204));

    render(<TodoContainer/>);
    expect(await screen.findByText("Plan")).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("New task"), {target: {value: "Write tests"}});
    fireEvent.click(screen.getByRole("button", {name: "Add task"}));
    expect(await screen.findByText("Write tests")).toBeInTheDocument();
    expect(global.fetch.mock.calls[1][0].toString()).toBe("http://localhost/api/items/");
    expect(JSON.parse(global.fetch.mock.calls[1][1].body)).toEqual({
        title: "Write tests",
        checked: false,
    });

    fireEvent.click(screen.getByRole("button", {name: 'Edit "Plan"'}));
    fireEvent.change(screen.getByLabelText("Edit task"), {target: {value: "Plan week"}});
    fireEvent.click(screen.getByRole("button", {name: "Save"}));
    expect(await screen.findByText("Plan week")).toBeInTheDocument();
    expect(global.fetch.mock.calls[2][0].toString()).toBe("http://localhost/api/items/1");
    expect(JSON.parse(global.fetch.mock.calls[2][1].body)).toEqual({title: "Plan week"});

    fireEvent.click(screen.getByRole("checkbox", {name: 'Mark "Plan week" as completed'}));
    await waitFor(() => expect(global.fetch).toHaveBeenCalledTimes(4));
    expect(JSON.parse(global.fetch.mock.calls[3][1].body)).toEqual({checked: true});
    expect(await screen.findByRole("checkbox", {name: 'Mark "Plan week" as open'})).toBeChecked();

    fireEvent.click(screen.getByRole("button", {name: 'Delete "Plan week"'}));
    fireEvent.click(screen.getByRole("button", {name: "Confirm"}));
    await waitFor(() => expect(screen.queryByText("Plan week")).not.toBeInTheDocument());
    expect(global.fetch.mock.calls[4][1]).toEqual({method: "DELETE"});
});

test("treats an empty successful response as an empty task list", async () => {
    global.fetch.mockResolvedValueOnce(apiResponse(null, 204));

    render(<TodoContainer/>);

    expect(await screen.findByText("No tasks yet. Add your first task above.")).toBeInTheDocument();
    expect(screen.getByText("0 tasks left")).toBeInTheDocument();
});

test("refetches after a successful create with no response body", async () => {
    global.fetch
        .mockResolvedValueOnce(apiResponse([]))
        .mockResolvedValueOnce(apiResponse(null, 204))
        .mockResolvedValueOnce(apiResponse([{id: 7, title: "Persisted task", checked: false}]));

    render(<TodoContainer/>);
    await screen.findByText("No tasks yet. Add your first task above.");

    fireEvent.change(screen.getByLabelText("New task"), {target: {value: "Persisted task"}});
    fireEvent.click(screen.getByRole("button", {name: "Add task"}));

    expect(await screen.findByText("Persisted task")).toBeInTheDocument();
    expect(global.fetch).toHaveBeenCalledTimes(3);
});

test("shows API errors and retains a task that failed to save", async () => {
    global.fetch
        .mockResolvedValueOnce(apiResponse([]))
        .mockResolvedValueOnce(apiResponse({detail: "Title is required"}, 422));

    render(<TodoContainer/>);
    await screen.findByText("No tasks yet. Add your first task above.");

    const input = screen.getByLabelText("New task");
    fireEvent.change(input, {target: {value: "Keep this draft"}});
    fireEvent.click(screen.getByRole("button", {name: "Add task"}));

    expect(await screen.findByRole("alert")).toHaveTextContent(/request failed \(HTTP 422\)\. Title is required/);
    expect(input).toHaveValue("Keep this draft");
});
