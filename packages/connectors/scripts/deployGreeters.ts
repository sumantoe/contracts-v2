import { Contract, Signer, ContractTransaction } from 'ethers'
import { ethers } from 'hardhat'
import { getSigners, logContractDeployed } from '../utils'
import { connectorFactories } from './config'

async function main() {
  const hubChainId = '5'
  const spokeChainId = '420'

  const signers = getSigners()
  const hubSigner = signers[hubChainId]
  const spokeSigner = signers[spokeChainId]

  // Deploy factories
  const HubERC5164ConnectorFactory = await ethers.getContractFactory(
    'HubERC5164ConnectorFactory'
  )
  const hubConnectorFactory = await HubERC5164ConnectorFactory.connect(
    hubSigner
  ).attach(connectorFactories[hubChainId])
  await logContractDeployed('HubERC5164ConnectorFactory', hubConnectorFactory)

  const ERC5164ConnectorFactory = await ethers.getContractFactory(
    'ERC5164ConnectorFactory'
  )
  const spokeConnectorFactory = await ERC5164ConnectorFactory.connect(
    spokeSigner
  ).attach(connectorFactories[spokeChainId])
  await logContractDeployed('ERC5164ConnectorFactory', spokeConnectorFactory)

  // Deploy Greeters on both chains
  const Greeter = await ethers.getContractFactory('BidirectionalGreeter')
  const greeter1 = await Greeter.connect(hubSigner).deploy()
  await logContractDeployed('Greeter', greeter1)

  const greeter2 = await Greeter.connect(spokeSigner).deploy()
  await logContractDeployed('Greeter', greeter2)

  const tx = await hubConnectorFactory.connectTargets(
    hubChainId,
    greeter1.address,
    spokeChainId,
    greeter2.address,
    { gasLimit: 1000000 }
  )

  const receipt = await tx.wait()
  const event = receipt.events?.find(
    event => event.event === 'ConnectorDeployed'
  )
  const connectorAddrs = event?.args?.connector

  const ERC5164Connector = await ethers.getContractFactory('ERC5164Connector')
  const hubConnector = await ERC5164Connector.connect(hubSigner).attach(
    connectorAddrs
  )
  await logContractDeployed('ERC5164Connector', hubConnector)

  console.log('Wait 2 minutes...')
  await wait(120_000)

  const spokeConnector = await ERC5164Connector.connect(spokeSigner).attach(
    connectorAddrs
  )
  await logContractDeployed('ERC5164Connector', spokeConnector)

  await greeter1.setConnector(connectorAddrs)
  await greeter2.setConnector(connectorAddrs)

  console.log('Greeters connected')
}

async function wait(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
