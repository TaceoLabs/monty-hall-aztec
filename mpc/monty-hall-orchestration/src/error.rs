use axum::{Json, http::StatusCode, response::IntoResponse};
use serde::{Serialize, Serializer};

pub type ApiResult<T> = Result<T, ApiErrors>;

#[derive(Debug, Serialize)]
pub struct ApiError {
    pub message: Option<String>,
    #[serde(serialize_with = "serialize_status_code")]
    pub code: StatusCode,
}

#[derive(Debug, thiserror::Error)]
pub enum ApiErrors {
    #[error("an explict error was returned: {0:?}")]
    ExplicitError(ApiError),
    #[error("user is not authorized to perform this action")]
    Unauthorized,
    #[error("user sent a misformed request: \"{0}\"")]
    BadRequest(String),
    //#[error("generic wrapper for error that is already sent to user")]
    //ResponseError(Response),
    #[error(transparent)]
    InternalSeverError(#[from] eyre::Report),
}

impl ApiError {
    pub fn new(status_code: StatusCode, error: String) -> Self {
        Self {
            message: Some(error),
            code: status_code,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        (self.code, Json(self)).into_response()
    }
}

impl IntoResponse for ApiErrors {
    fn into_response(self) -> axum::response::Response {
        match self {
            ApiErrors::ExplicitError(inner) => inner.into_response(),
            ApiErrors::InternalSeverError(inner) => {
                tracing::error!("{inner:#?}");
                StatusCode::INTERNAL_SERVER_ERROR.into_response()
            }
            ApiErrors::BadRequest(message) => (StatusCode::BAD_REQUEST, message).into_response(),
            //ApiErrors::ResponseError(response) => response,
            ApiErrors::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "User is not authorized to perform this action",
            )
                .into_response(),
        }
    }
}

fn serialize_status_code<S>(x: &StatusCode, s: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    s.serialize_u16(x.as_u16())
}
