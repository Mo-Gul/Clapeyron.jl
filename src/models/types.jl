abstract type LatticeFluidModel <: EoSModel end
abstract type AssociationModel <: LatticeFluidModel end
abstract type CPAModel <: AssociationModel end
abstract type SAFTModel <: AssociationModel end
abstract type GCSAFTModel <: SAFTModel end

abstract type CubicModel <: EoSModel end
abstract type ABCubicModel <: CubicModel end #cubics that have an exact polynomial form to solve Z roots, this excludes CPA
abstract type ActivityModel <: EoSModel end
abstract type IdealModel <: EoSModel end
abstract type EmpiricHelmholtzModel <: EoSModel end
abstract type SatPureAproximation <: EoSModel end
abstract type AlphaModel <:EoSModel end
abstract type ElectrolyteModel <: EoSModel end
abstract type IonModel <: EoSModel end
abstract type RSPModel <: EoSModel end

export SAFTModel,CubicModel,EmpiricHelmholtzModel
export IdealModel
export AlphaModel
