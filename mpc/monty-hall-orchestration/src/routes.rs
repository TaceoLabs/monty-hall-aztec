use axum::{Router, routing::get};

use crate::AppState;

pub mod user;

pub fn create_routes(app_state: AppState) -> Router {
    Router::new()
        .route("/new_game/{addr}", get(user::new_game))
        .with_state(app_state)
}
