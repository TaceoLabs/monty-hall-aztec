use protos::monty_hall::{
    NewGameRequest, NewGameResponse, SampleRandRequest, SampleRandResponse,
    mpc_node_service_client::MpcNodeServiceClient,
};
use tokio::sync::{mpsc, oneshot};

type RootRand = oneshot::Sender<Result<SampleRandResponse, tonic::Status>>;

struct NewGame {
    tx: oneshot::Sender<Result<NewGameResponse, tonic::Status>>,
}

enum MpcNodeJob {
    RootRand(RootRand),
    NewGame(NewGame),
    RevealDoor(oneshot::Sender<Result<(), tonic::Status>>),
}

#[derive(Clone, Debug)]
pub struct MpcNodeHandle {
    handle: mpsc::Sender<MpcNodeJob>,
}

pub(super) async fn connect(addr: &str) -> eyre::Result<MpcNodeHandle> {
    let addr = addr.to_string();
    let (tx, mut rx) = mpsc::channel(4);
    let (finished_tx, finished_rx) = oneshot::channel();
    tokio::spawn(async move {
        let mut client = match MpcNodeServiceClient::connect(addr.to_string()).await {
            Ok(client) => {
                let _ = finished_tx.send(Ok(()));
                client
            }
            Err(err) => {
                let _ = finished_tx.send(Err(err));
                return;
            }
        };
        while let Some(job) = rx.recv().await {
            match job {
                MpcNodeJob::RootRand(tx) => {
                    let result = client.sample_rand(SampleRandRequest {}).await;
                    let _ = tx.send(result.map(|result| result.into_inner()));
                }
                MpcNodeJob::NewGame(new_game) => {
                    let result = client
                        .new_game(NewGameRequest {
                            seed_share: vec![],
                            seed_commitment: vec![],
                        })
                        .await;

                    let _ = new_game.tx.send(result.map(|result| result.into_inner()));
                }
                MpcNodeJob::RevealDoor(sender) => todo!(),
            }
        }
    });
    finished_rx.await??;
    Ok(MpcNodeHandle { handle: tx })
}

impl MpcNodeHandle {
    pub(crate) async fn sample_root_rand(&self) -> eyre::Result<SampleRandResponse> {
        let (tx, rx) = oneshot::channel();
        self.handle.send(MpcNodeJob::RootRand(tx)).await?;
        rx.await.unwrap().map_err(|err| eyre::eyre!(err))
    }
    pub(crate) async fn new_game(&self) -> eyre::Result<NewGameResponse> {
        let (tx, rx) = oneshot::channel();
        self.handle
            .send(MpcNodeJob::NewGame(NewGame { tx }))
            .await?;
        rx.await.unwrap().map_err(|err| eyre::eyre!(err))
    }
    pub(crate) async fn reveal_door(&self) -> eyre::Result<NewGameResponse> {
        let (tx, rx) = oneshot::channel();
        self.handle
            .send(MpcNodeJob::NewGame(NewGame { tx }))
            .await?;
        rx.await.unwrap().map_err(|err| eyre::eyre!(err))
    }
}
