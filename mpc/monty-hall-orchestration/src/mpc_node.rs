use eyre::eyre;
use protos::monty_hall::{NewGameRequest, mpc_node_service_client::MpcNodeServiceClient};
use tokio::sync::{mpsc, oneshot};

struct NewGame {
    addr: ark_bn254::Fr,
    tx: oneshot::Sender<eyre::Result<()>>,
}

enum MpcNodeJob {
    NewGame(NewGame),
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
                MpcNodeJob::NewGame(new_game) => {
                    let result = client
                        .new_game(NewGameRequest {
                            seed_share: vec![],
                            seed_commitment: vec![],
                        })
                        .await
                        .unwrap();
                    tracing::info!("answer: {:?}", result.into_inner());
                    let _ = new_game.tx.send(Ok(()));
                }
            }
        }
    });
    finished_rx.await??;
    Ok(MpcNodeHandle { handle: tx })
}

impl MpcNodeHandle {
    pub(crate) async fn new_game(&self, addr: ark_bn254::Fr) -> eyre::Result<()> {
        let (tx, rx) = oneshot::channel();
        self.handle
            .send(MpcNodeJob::NewGame(NewGame { addr, tx }))
            .await?;
        rx.await?
    }
}
