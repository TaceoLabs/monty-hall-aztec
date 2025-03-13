use axum::{
    extract::{Path, State},
    http::StatusCode,
};

use crate::{
    AppState,
    error::{ApiErrors, ApiResult},
};

pub async fn new_game(
    State(state): State<AppState>,
    Path(addr): Path<String>,
) -> ApiResult<StatusCode> {
    tracing::debug!("new game from {addr}");
    let addr = addr
        .parse()
        .map_err(|_| ApiErrors::BadRequest(format!("Invalid address: {addr}")))?;
    let result = state.node0.new_game(addr).await.unwrap();
    Ok(StatusCode::OK)
}
