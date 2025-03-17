use axum::{Router, routing::get};

use crate::AppState;

pub mod user;

pub fn create_routes(app_state: AppState) -> Router {
    Router::new()
        .route("/sample_rand", get(user::sample_root_rand))
        .route("/new_game", get(user::new_game))
        .route("/reveal_door", get(user::reveal_door))
        .with_state(app_state)
}
