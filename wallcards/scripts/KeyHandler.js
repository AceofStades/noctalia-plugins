function handleKey(event, bindings) {
    const action = bindings[event.key];
    if (action) {
        action();
        event.accepted = true;
    }
}
