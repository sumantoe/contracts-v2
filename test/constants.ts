import { BigNumber } from 'ethers'
import { getSetResultCalldata } from './utils'

export const ONE_WEEK = 604800

export const HUB_CHAIN_ID = BigNumber.from(1110)
export const SPOKE_CHAIN_ID_0 = BigNumber.from(1111)
export const SPOKE_CHAIN_ID_1 = BigNumber.from(1112)
export const TREASURY = '0x1111000000000000000000000000000000001111'
export const PUBLIC_GOODS = '0x2222000000000000000000000000000000002222'
export const MIN_PUBLIC_GOODS_BPS = 100_000

// Fee distribution
export const FULL_POOL_SIZE = 100_000

// Fee collection
export const MAX_BUNDLE_MESSAGES = 2
export const MESSAGE_FEE = 100

// Message
export const DEFAULT_RESULT = 12345
export const DEFAULT_FROM_CHAIN_ID = SPOKE_CHAIN_ID_0
export const DEFAULT_TO_CHAIN_ID = HUB_CHAIN_ID
export const DEFAULT_DATA = getSetResultCalldata(DEFAULT_RESULT)
